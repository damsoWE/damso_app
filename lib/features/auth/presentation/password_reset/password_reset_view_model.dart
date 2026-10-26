import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/error_codes.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/session/session_state.dart';
import '../../../../core/validation/validators.dart';
import '../../../me/data/me_repository_provider.dart';
import '../../data/auth_repository_provider.dart';

enum ResetStep { emailEntry, codeEntry, expiredOrLocked, newPassword, done }

/// 비밀번호 재설정 상태(data-model §2). 확인된 코드는 메모리에만 둔다.
class PasswordResetState {
  const PasswordResetState({
    this.step = ResetStep.emailEntry,
    this.email = '',
    this.code = '',
    this.errorMessage,
    this.notice,
    this.fieldErrors = const {},
    this.isSubmitting = false,
  });

  final ResetStep step;
  final String email;
  final String code;
  final String? errorMessage;
  final String? notice;
  final Map<String, String> fieldErrors;
  final bool isSubmitting;

  PasswordResetState copyWith({
    ResetStep? step,
    String? email,
    String? code,
    String? Function()? errorMessage,
    String? Function()? notice,
    Map<String, String>? fieldErrors,
    bool? isSubmitting,
  }) {
    return PasswordResetState(
      step: step ?? this.step,
      email: email ?? this.email,
      code: code ?? this.code,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      notice: notice != null ? notice() : this.notice,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// C-3 → C-3b/C-3c → C-4 → C-5.
class PasswordResetViewModel extends Notifier<PasswordResetState> {
  static const _sentNotice = '입력한 이메일로 안내를 보냈습니다.';

  @override
  PasswordResetState build() => const PasswordResetState();

  void _start() => state = state.copyWith(
    isSubmitting: true,
    errorMessage: () => null,
    notice: () => null,
    fieldErrors: const {},
  );

  void _fail(AppException e, {ResetStep? step}) => state = state.copyWith(
    step: step,
    isSubmitting: false,
    errorMessage: () => e.message,
    fieldErrors: e.fieldErrors,
  );

  bool _isExpiredOrLocked(AppException e) =>
      e.code == ErrorCodes.tooManyAttempts;

  /// 가입 여부와 관계없이 같은 안내(FR-023). 성공하면 true.
  Future<bool> requestReset(String email) async {
    if (state.isSubmitting) return false;
    final clientError = validateEmail(email);
    if (clientError != null) {
      state = state.copyWith(fieldErrors: {'email': clientError});
      return false;
    }
    final trimmed = email.trim();
    _start();
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(trimmed);
      state = state.copyWith(
        step: ResetStep.codeEntry,
        email: trimmed,
        isSubmitting: false,
        notice: () => _sentNotice,
      );
      return true;
    } on AppException catch (e) {
      _fail(e);
      return false;
    } finally {
      link.close();
    }
  }

  /// 성공하면 true(→ C-4). 만료·5회 실패면 C-3c 상태가 된다(FR-024).
  Future<bool> verifyCode(String raw) async {
    if (state.isSubmitting) return false;
    final clientError = validateSixDigitCode(raw);
    if (clientError != null) {
      state = state.copyWith(errorMessage: () => clientError);
      return false;
    }
    final code = normalizeSixDigitCode(raw);
    _start();
    final link = ref.keepAlive();
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetCode(state.email, code);
      state = state.copyWith(
        step: ResetStep.newPassword,
        code: code,
        isSubmitting: false,
      );
      return true;
    } on AppException catch (e) {
      _fail(e, step: _isExpiredOrLocked(e) ? ResetStep.expiredOrLocked : null);
      return false;
    } finally {
      link.close();
    }
  }

  /// C-3c "코드 다시 받기".
  Future<void> resendCode() async {
    if (state.isSubmitting) return;
    _start();
    final link = ref.keepAlive();
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(state.email);
      state = state.copyWith(
        step: ResetStep.codeEntry,
        code: '',
        isSubmitting: false,
        notice: () => _sentNotice,
      );
    } on AppException catch (e) {
      _fail(e);
    } finally {
      link.close();
    }
  }

  /// 성공하면 true(→ C-5). 내 계정을 재설정했다면 이 기기도 로그아웃한다(FR-025).
  /// 다른 계정을 재설정했다면 지금 로그인한 세션은 그대로 둔다.
  Future<bool> confirm(String newPassword) async {
    if (state.isSubmitting) return false;
    final clientError = validateNewPassword(newPassword);
    if (clientError != null) {
      state = state.copyWith(fieldErrors: {'newPassword': clientError});
      return false;
    }
    _start();
    final link = ref.keepAlive();
    try {
      // 재설정 뒤에는 그 계정의 세션이 폐기돼 내 정보를 조회할 수 없으므로 먼저 확인한다.
      final ownAccount = await _isSignedInAs(state.email);
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(state.email, state.code, newPassword);
      if (ownAccount) {
        await ref.read(sessionControllerProvider.notifier).signOut();
      }
      state = state.copyWith(step: ResetStep.done, code: '', isSubmitting: false);
      return true;
    } on AppException catch (e) {
      // 그사이 코드가 만료되었으면 C-3c 로 보낸다.
      final expired =
          e.code == ErrorCodes.invalidVerificationCode || _isExpiredOrLocked(e);
      _fail(e, step: expired ? ResetStep.expiredOrLocked : null);
      return false;
    } finally {
      link.close();
    }
  }

  /// 로그인 상태이고 [email] 이 내 계정이면 true. 확인할 수 없으면 true(안전하게 로그아웃).
  Future<bool> _isSignedInAs(String email) async {
    if (ref.read(sessionControllerProvider) is! SignedIn) return false;
    try {
      final me = await ref.read(meRepositoryProvider).getMe();
      return me.email.toLowerCase() == email.toLowerCase();
    } on AppException {
      return true;
    }
  }
}

final passwordResetViewModelProvider =
    NotifierProvider.autoDispose<PasswordResetViewModel, PasswordResetState>(
      PasswordResetViewModel.new,
    );
