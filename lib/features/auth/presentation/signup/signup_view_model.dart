import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/error_codes.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../data/auth_repository_provider.dart';
import '../../domain/models.dart';

enum SignupStep { codeEntry, accountForm, verifying }

/// 화면 이동 지시. 화면은 이 값에 따라 push/pop 만 한다.
enum SignupOutcome { stay, next, backToCode }

/// 가입 흐름 상태(data-model §2). 비밀번호는 담지 않는다.
class SignupState {
  const SignupState({
    this.step = SignupStep.codeEntry,
    this.inviteRole,
    this.inviteCode = '',
    this.name = '',
    this.email = '',
    this.pending,
    this.errorMessage,
    this.notice,
    this.fieldErrors = const {},
    this.attemptCooldown = Cooldown.none,
    this.resendCooldown = Cooldown.none,
    this.isSubmitting = false,
  });

  final SignupStep step;
  final InviteRole? inviteRole;
  final String inviteCode;
  final String name;
  final String email;

  /// 메모리 전용. 가입 화면을 모두 벗어나면 사라진다(research R10).
  final PendingSignup? pending;
  final String? errorMessage;
  final String? notice;
  final Map<String, String> fieldErrors;

  /// 현재 단계 제출 버튼의 잠금. 단계가 바뀌면 초기화한다.
  final Cooldown attemptCooldown;

  /// 인증 코드 재발송 전용.
  final Cooldown resendCooldown;
  final bool isSubmitting;

  SignupState copyWith({
    SignupStep? step,
    InviteRole? inviteRole,
    String? inviteCode,
    String? name,
    String? email,
    PendingSignup? pending,
    String? Function()? errorMessage,
    String? Function()? notice,
    Map<String, String>? fieldErrors,
    Cooldown? attemptCooldown,
    Cooldown? resendCooldown,
    bool? isSubmitting,
  }) {
    return SignupState(
      step: step ?? this.step,
      inviteRole: inviteRole ?? this.inviteRole,
      inviteCode: inviteCode ?? this.inviteCode,
      name: name ?? this.name,
      email: email ?? this.email,
      pending: pending ?? this.pending,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      notice: notice != null ? notice() : this.notice,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      attemptCooldown: attemptCooldown ?? this.attemptCooldown,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class SignupViewModel extends Notifier<SignupState> {
  final _attemptTimer = CooldownTimer();
  final _resendTimer = CooldownTimer();

  @override
  SignupState build() {
    ref.onDispose(() {
      _attemptTimer.cancel();
      _resendTimer.cancel();
    });
    return const SignupState();
  }

  bool get _blocked => state.isSubmitting || state.attemptCooldown.isActive;

  /// F1-1 코드 확인.
  Future<SignupOutcome> submitCode(String raw) async {
    if (_blocked) return SignupOutcome.stay;
    final clientError = validateInviteCode(raw);
    if (clientError != null) {
      state = state.copyWith(errorMessage: () => clientError);
      return SignupOutcome.stay;
    }
    final code = normalizeInviteCode(raw);
    _startSubmit();
    try {
      final role = await ref.read(authRepositoryProvider).checkInviteCode(code);
      _moveTo(SignupStep.accountForm);
      state = SignupState(
        step: SignupStep.accountForm,
        inviteRole: role,
        inviteCode: code,
        name: state.name,
        email: state.email,
      );
      return SignupOutcome.next;
    } on AppException catch (e) {
      _fail(e);
      return SignupOutcome.stay;
    }
  }

  /// F1-3/F1-3a 계정 정보 제출.
  Future<SignupOutcome> submitAccount({
    required String name,
    required String email,
    required String password,
    required bool termsAgreed,
  }) async {
    if (_blocked) return SignupOutcome.stay;
    final errors = <String, String>{
      'name': ?validateName(name),
      'email': ?validateEmail(email),
      'password': ?validateNewPassword(password),
    };
    if (errors.isNotEmpty || !termsAgreed) {
      state = state.copyWith(
        fieldErrors: errors,
        errorMessage: () => termsAgreed ? null : '약관에 동의해 주세요.',
      );
      return SignupOutcome.stay;
    }
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    state = state.copyWith(name: trimmedName, email: trimmedEmail);
    _startSubmit();
    try {
      final pending = await ref
          .read(authRepositoryProvider)
          .startSignup(
            SignupForm(
              inviteCode: state.inviteCode,
              name: trimmedName,
              email: trimmedEmail,
              password: password,
              termsAgreed: termsAgreed,
            ),
          );
      _moveTo(SignupStep.verifying);
      state = state.copyWith(
        step: SignupStep.verifying,
        pending: pending,
        isSubmitting: false,
      );
      return SignupOutcome.next;
    } on AppException catch (e) {
      if (e.code == ErrorCodes.invalidInviteCode) {
        _backToCode(e.message);
        return SignupOutcome.backToCode;
      }
      _fail(e);
      return SignupOutcome.stay;
    }
  }

  /// C-2 인증. 성공하면 세션이 바뀌고 라우터가 이용 안내(C-6)로 보낸다.
  Future<SignupOutcome> verify(String raw) async {
    final pending = state.pending;
    if (_blocked || pending == null) return SignupOutcome.stay;
    final clientError = validateSixDigitCode(raw);
    if (clientError != null) {
      state = state.copyWith(errorMessage: () => clientError);
      return SignupOutcome.stay;
    }
    _startSubmit();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verifySignup(pending.pendingSignupId, normalizeSixDigitCode(raw));
      state = state.copyWith(isSubmitting: false);
      ref
          .read(sessionControllerProvider.notifier)
          .signIn(result.role, justSignedUp: true);
      return SignupOutcome.next;
    } on AppException catch (e) {
      if (e.code == ErrorCodes.invalidInviteCode) {
        _backToCode(e.message); // 그사이 초대 코드가 재발행·만료됨
        return SignupOutcome.backToCode;
      }
      _fail(e);
      return SignupOutcome.stay;
    }
  }

  /// 인증 코드 재발송. 60초에 한 번(FR-018). 429 는 재발송 버튼만 잠근다.
  Future<void> resend() async {
    final pending = state.pending;
    if (pending == null ||
        state.isSubmitting ||
        state.resendCooldown.isActive) {
      return;
    }
    state = state.copyWith(errorMessage: () => null, notice: () => null);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupCode(pending.pendingSignupId);
      state = state.copyWith(notice: () => '새 인증 코드를 보냈습니다. 이전 코드는 더 이상 사용할 수 없습니다.');
      _resendTimer.start(const Duration(seconds: 60), _onResendTick);
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: () => e.message);
      if (e.code == ErrorCodes.tooManyAttempts) {
        _resendTimer.start(e.retryAfter, _onResendTick);
      }
    }
  }

  void backToCode() => _backToCode(null);

  void _startSubmit() {
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: () => null,
      notice: () => null,
      fieldErrors: const {},
    );
  }

  void _fail(AppException e) {
    state = state.copyWith(
      isSubmitting: false,
      errorMessage: () => e.message,
      fieldErrors: e.fieldErrors,
    );
    if (e.code == ErrorCodes.tooManyAttempts) {
      _attemptTimer.start(e.retryAfter, _onAttemptTick);
    }
  }

  void _moveTo(SignupStep step) {
    if (step != state.step) {
      _attemptTimer.cancel();
      state = state.copyWith(attemptCooldown: Cooldown.none);
    }
  }

  void _backToCode(String? message) {
    _attemptTimer.cancel();
    _resendTimer.cancel();
    state = SignupState(
      inviteCode: state.inviteCode,
      name: state.name,
      email: state.email,
      errorMessage: message,
    );
  }

  void _onAttemptTick(Cooldown c) =>
      state = state.copyWith(attemptCooldown: c);

  void _onResendTick(Cooldown c) => state = state.copyWith(resendCooldown: c);
}

final signupViewModelProvider =
    NotifierProvider.autoDispose<SignupViewModel, SignupState>(
      SignupViewModel.new,
    );
