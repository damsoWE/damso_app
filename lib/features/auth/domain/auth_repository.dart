import '../../../core/session/role.dart';
import 'models.dart';

/// 인증 도메인 계약(contracts/api-usage.md auth). 실서버 / mock 구현이 모두 이 클래스를 따른다.
/// 연락처(전화번호·주소)는 다루지 않는다(원칙 1).
abstract class AuthRepository {
  /// 가입 전 초대 코드 확인. 코드를 소모하지 않고 역할만 알려 준다.
  /// 실패 횟수는 [email] 기준으로 가입 1단계와 합산된다(api-v0.4).
  Future<InviteRole> checkInviteCode({
    required String code,
    required String email,
  });

  Future<PendingSignup> startSignup(SignupForm form);

  /// 성공하면 토큰 보관은 구현체가 맡는다(AT 메모리, RT 보안 저장소).
  Future<AuthResult> verifySignup(String pendingSignupId, String code);

  Future<void> resendSignupCode(String pendingSignupId);

  Future<AuthResult> login({required String email, required String password});

  /// 앱 시작 시 1회. 저장된 토큰이 없으면 null.
  /// 서버가 거부하면(401) 토큰을 지우고 AppException 을, 네트워크 오류면
  /// `isNetworkError` AppException 을 던진다.
  Future<Role?> restoreSession();

  /// 서버 결과와 관계없이 기기의 토큰은 지운다.
  Future<void> logout();

  Future<void> requestPasswordReset(String email);

  Future<void> verifyPasswordResetCode(String email, String code);

  /// 성공하면 이 기기의 토큰도 지운다(모든 세션 폐기).
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String newPassword,
  );
}
