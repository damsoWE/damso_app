import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 토큰 보관 규칙: AT 는 메모리에만, RT 는 OS 보안 저장소에만 둔다.
class TokenStore {
  TokenStore([FlutterSecureStorage? secure])
    : _secure = secure ?? const FlutterSecureStorage();

  static const _refreshKey = 'refresh_token';
  final FlutterSecureStorage _secure;

  String? accessToken; // 메모리 전용. 앱 종료 시 사라진다.

  Future<String?> readRefreshToken() => _secure.read(key: _refreshKey);

  Future<void> saveRefreshToken(String token) =>
      _secure.write(key: _refreshKey, value: token);

  Future<void> clear() async {
    accessToken = null;
    await _secure.delete(key: _refreshKey);
  }
}
