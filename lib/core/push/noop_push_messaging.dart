import 'push_messaging.dart';

/// 알림이 없는 실행(mock·테스트·Firebase 설정 없음). 아무 일도 하지 않는다.
class NoopPushMessaging implements PushMessaging {
  const NoopPushMessaging();

  @override
  bool get isAvailable => false;

  @override
  String get platform => 'ANDROID';

  @override
  Future<PushPermission> permissionStatus() async => PushPermission.denied;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();

  @override
  Stream<PushData> get onMessageOpened => const Stream.empty();

  @override
  Future<PushData?> initialMessage() async => null;
}
