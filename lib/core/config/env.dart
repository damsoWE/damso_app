import 'package:flutter/foundation.dart';

/// 빌드 시점 환경값. --dart-define-from-file=env/<환경>.json 으로 주입한다.
/// 시크릿(API 키 등)은 앱에 넣지 않는다. 서버 주소 같은 공개 가능한 값만 둔다.
/// Firebase 연결 값은 저장소에 두지 않고 `secrets/firebase.json`으로 빌드 때만 주입한다
/// (specs/002-inquiry-intake-urgent research R10).
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// true 면 Repository 를 mock 구현으로 전환한다(서버 불필요).
  static const useMock = bool.fromEnvironment('USE_MOCK');

  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );

  /// 기기 알림을 켤 수 있는 값이 모두 있는지. 없으면 알림 없이 동작한다.
  static bool get hasFirebase =>
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      (firebaseAndroidAppId.isNotEmpty || firebaseIosAppId.isNotEmpty);

  /// 미설정 시 기동을 거부한다(원칙 8: 설정 누락 상태로 실행하지 않음).
  /// 릴리스 빌드는 mock 과 평문(http) 서버 주소를 허용하지 않는다.
  /// (mock 은 공용 비밀번호의 데모 계정을 쓰고, http 는 토큰·민원을 평문으로 보낸다.)
  static void ensureConfigured() {
    if (kReleaseMode && useMock) {
      throw StateError(
        '릴리스 빌드에서는 USE_MOCK 을 켤 수 없습니다. '
        '--dart-define-from-file=env/prod.json 으로 빌드하세요(scripts/build-release.sh).',
      );
    }
    if (!useMock && apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL 이 설정되지 않았습니다. '
        '--dart-define-from-file=env/prod.json(배포 서버) 또는 env/dev.json(로컬 서버)으로 실행하세요.',
      );
    }
    if (kReleaseMode && !apiBaseUrl.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL 은 릴리스 빌드에서 https:// 로 시작해야 합니다. '
        '--dart-define-from-file=env/prod.json 으로 빌드하세요.',
      );
    }
  }
}
