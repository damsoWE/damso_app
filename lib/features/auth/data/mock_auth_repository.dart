import '../../../core/error/app_exception.dart';
import '../domain/auth_repository.dart';

/// mock 구현(서버 불필요). 비밀번호가 비어 있으면 401 로 실패해 오류 화면을 확인할 수 있다.
class MockAuthRepository implements AuthRepository {
  @override
  Future<void> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (password.isEmpty) {
      throw const AppException(
        message: '이메일 또는 비밀번호를 확인해 주세요.',
        statusCode: 401,
      );
    }
  }

  @override
  Future<void> logout() async {}
}
