import '../../../core/session/role.dart';

/// 초대 코드 확인 결과(`POST /api/v1/auth/invite-codes/verify`, research R5).
enum InviteRole { teacher, parent }

/// 가입 입력(openapi `SignupRequest`). 연락처 필드는 두지 않는다(원칙 1).
class SignupForm {
  const SignupForm({
    required this.inviteCode,
    required this.name,
    required this.email,
    required this.password,
    required this.termsAgreed,
  });

  final String inviteCode;
  final String name;
  final String email;
  final String password;
  final bool termsAgreed;
}

/// 가입 입력 후 인증 코드 입력까지의 대기 상태. 메모리 전용(research R10).
class PendingSignup {
  const PendingSignup({
    required this.pendingSignupId,
    required this.codeExpiresIn,
  });

  final String pendingSignupId;
  final Duration codeExpiresIn;
}

/// 로그인·가입 완료 결과. 토큰은 Repository 가 저장하고 역할만 위로 올린다.
class AuthResult {
  const AuthResult({required this.role});

  final Role role;
}
