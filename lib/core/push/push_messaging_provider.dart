import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'fcm_push_messaging.dart';
import 'noop_push_messaging.dart';
import 'push_messaging.dart';

/// Firebase 초기화에 성공했는지. main.dart 의 [initPushMessaging] 이 정한다.
bool _firebaseReady = false;

/// Firebase 설정 값이 있을 때만 초기화한다(research R10). 실패해도 앱은 알림 없이 동작한다.
Future<void> initPushMessaging() async {
  if (Env.useMock || !Env.hasFirebase) return;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: ios ? Env.firebaseIosAppId : Env.firebaseAndroidAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        iosBundleId: ios ? Env.firebaseIosBundleId : null,
      ),
    );
    _firebaseReady = true;
  } catch (_) {
    // 설정 오류·네트워크 문제 — 내용은 남기지 않고 알림만 끈다.
    _firebaseReady = false;
  }
}

/// 구현체를 고르는 유일한 지점.
final pushMessagingProvider = Provider<PushMessaging>((_) {
  if (Env.useMock || !_firebaseReady) return const NoopPushMessaging();
  return FcmPushMessaging();
});
