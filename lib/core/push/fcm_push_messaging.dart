import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_messaging.dart';

/// FCM 구현. 토큰·알림 데이터는 로그·저장하지 않는다(FR-031c).
/// 앱이 열려 있을 때는 시스템 알림이 뜨지 않으므로 앱 안 배너로 보인다(research R9).
class FcmPushMessaging implements PushMessaging {
  FcmPushMessaging([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  bool get isAvailable => true;

  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<PushPermission> permissionStatus() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(
    (m) => PushMessage(
      title: m.notification?.title ?? '',
      body: m.notification?.body ?? '',
      data: PushData.fromMap(m.data),
    ),
  );

  @override
  Stream<PushData> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => PushData.fromMap(m.data));

  @override
  Future<PushData?> initialMessage() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : PushData.fromMap(m.data);
  }
}
