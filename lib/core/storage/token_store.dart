import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

/// 토큰 보관 규칙: AT 는 메모리에만, RT 는 OS 보안 저장소에만 둔다.
class TokenStore {
  TokenStore([FlutterSecureStorage? secure])
    : _secure = secure ?? _defaultStorage;

  /// iOS 기본값(unlocked)은 암호화 백업에 실려 다른 기기로 복원될 수 있다.
  /// 이 기기에서만 쓰도록 ThisDeviceOnly 로 둔다(백그라운드 갱신을 위해 첫 잠금 해제 뒤 허용).
  /// 이전 접근 수준으로 저장된 토큰도 플러그인이 읽고 다시 쓸 때 옮겨 주므로 별도 이전 코드는 없다.
  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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
