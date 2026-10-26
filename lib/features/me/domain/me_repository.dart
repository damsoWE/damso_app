import 'me.dart';

/// 마이페이지 공통 계약(contracts/api-usage.md me).
abstract class MeRepository {
  Future<Me> getMe();

  Future<Me> updateName(String name);

  /// 성공하면 기기의 토큰을 지운다. 비밀번호가 틀리면 INVALID_CREDENTIALS(401),
  /// 슈퍼 관리자는 FORBIDDEN.
  Future<void> withdraw(String password);
}
