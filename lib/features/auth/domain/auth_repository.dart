/// 인증 도메인 계약. 실서버 / mock 구현이 모두 이 클래스를 따른다.
/// 연락처(전화번호·주소)는 다루지 않는다(원칙 1).
abstract class AuthRepository {
  /// 성공하면 토큰 보관은 구현체가 맡는다(AT 메모리, RT 보안 저장소).
  Future<void> login({required String email, required String password});

  Future<void> logout();
}
