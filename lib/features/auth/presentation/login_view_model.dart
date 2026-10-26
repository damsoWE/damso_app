import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/cooldown.dart';
import '../data/auth_repository_provider.dart';

/// 로그인 화면 상태. 대기(C-1a)는 같은 화면의 [cooldown] 이다.
class LoginState {
  const LoginState({
    this.isSubmitting = false,
    this.errorMessage,
    this.fieldErrors = const {},
    this.cooldown = Cooldown.none,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final Cooldown cooldown;

  LoginState copyWith({
    bool? isSubmitting,
    String? Function()? errorMessage,
    Map<String, String>? fieldErrors,
    Cooldown? cooldown,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      cooldown: cooldown ?? this.cooldown,
    );
  }
}

/// 로그인 ViewModel. 성공하면 세션만 바꾸고 이동은 라우터 redirect 에 맡긴다.
/// 대기 횟수·시간은 서버가 정한다(FR-021) — 앱은 실패 횟수를 세지 않는다.
class LoginViewModel extends Notifier<LoginState> {
  final _timer = CooldownTimer();

  @override
  LoginState build() {
    ref.onDispose(_timer.cancel);
    return const LoginState();
  }

  Future<void> login({required String email, required String password}) async {
    if (state.isSubmitting || state.cooldown.isActive) return;
    final errors = <String, String>{
      'email': ?validateEmail(email),
      'password': ?validateCurrentPassword(password),
    };
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: () => null,
      fieldErrors: const {},
    );
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password);
      state = state.copyWith(isSubmitting: false);
      ref.read(sessionControllerProvider.notifier).signIn(result.role);
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.message,
        fieldErrors: e.fieldErrors,
      );
      if (e.code == ErrorCodes.tooManyAttempts) {
        _timer.start(e.retryAfter, (c) => state = state.copyWith(cooldown: c));
      }
    }
  }
}

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );
