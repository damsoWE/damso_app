import 'models.dart';

/// 교사 알림 설정·기기 등록(contracts/api-usage.md "notification").
abstract class NotificationRepository {
  Future<NotificationSettings> getSettings();

  Future<NotificationSettings> saveSettings(NotificationSettings settings);

  /// 이 기기를 지금 세션의 알림 수신 기기로 등록한다. 같은 토큰이면 갱신.
  Future<void> registerDevice({
    required String token,
    required DevicePlatform platform,
  });

  /// 이 세션의 기기 등록 해제(등록이 없어도 성공).
  Future<void> unregisterCurrentDevice();
}
