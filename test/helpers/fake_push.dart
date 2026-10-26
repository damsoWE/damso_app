import 'dart:async';

import 'package:damso_app/core/push/push_messaging.dart';

/// 위젯·단위 테스트용 가짜 기기 알림. 권한·토큰·수신을 테스트가 정한다.
class FakePush implements PushMessaging {
  FakePush({this.permission = PushPermission.granted, this.token = 'token-1'});

  PushPermission permission;

  /// requestPermission 을 받았을 때 바뀔 값.
  PushPermission answer = PushPermission.granted;
  String? token;

  /// getToken 이 던질 오류(APNs 토큰 없음 등).
  Object? tokenError;
  int requestCalls = 0;
  PushData? initial;

  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushData>.broadcast();
  final tokenRefresh = StreamController<String>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  String get platform => 'ANDROID';

  @override
  Future<PushPermission> permissionStatus() async => permission;

  @override
  Future<PushPermission> requestPermission() async {
    requestCalls++;
    return permission = answer;
  }

  @override
  Future<String?> getToken() async {
    final e = tokenError;
    if (e != null) throw e;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushData> get onMessageOpened => opened.stream;

  @override
  Future<PushData?> initialMessage() async => initial;
}
