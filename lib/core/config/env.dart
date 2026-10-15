/// 빌드 시점 환경값. --dart-define-from-file=env/<환경>.json 으로 주입한다.
/// 시크릿(API 키 등)은 앱에 넣지 않는다. 서버 주소 같은 공개 가능한 값만 둔다.
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 미설정 시 기동을 거부한다(원칙 8: 설정 누락 상태로 실행하지 않음).
  static void ensureConfigured() {
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL 이 설정되지 않았습니다. '
        '--dart-define-from-file=env/dev.json 으로 실행하세요.',
      );
    }
  }
}
