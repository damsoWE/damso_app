/// 인증 도메인 계약. mock / 실서버 구현이 모두 이 인터페이스를 따른다.
/// 연락처(전화번호·주소)는 다루지 않는다(원칙 1).
abstract interface class AuthRepository {
  /// 로그인 성공 시 토큰은 TokenStore 에 저장된다(AT 메모리, RT 보안 저장소).
  Future<void> login({required String email, required String password});

  Future<void> logout();
}
