import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/push/push_messaging.dart';
import '../../../core/push/push_messaging_provider.dart';
import '../../../core/session/role.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../data/notification_repository_provider.dart';
import '../domain/models.dart';

/// 교사 기기를 알림 수신 기기로 등록한다(spec FR-031, data-model §4 DeviceRegistrar).
/// - 교사로 로그인(세션 복구 포함)하면 권한이 허용된 경우 토큰을 등록하고, 토큰이 바뀌면 다시 등록한다.
/// - 권한은 교사 홈에 들어왔을 때 기기에서 아직 정하지 않은 경우에만 묻는다(FR-031a).
/// - 학부모·관리자는 등록하지 않는다(학부모는 F4).
/// - 등록에 실패했거나 나중에 기기 설정에서 알림을 켠 경우, 앱이 다시 앞으로 올 때 다시 시도한다.
/// 해제는 로그아웃·탈퇴 직전 MeViewModel 이 부르고, 세션이 끝나면 서버도 보내지 않는다.
/// 로그아웃·탈퇴 때는 서버 해제가 실패해도 기기 알림 토큰을 폐기해 이 기기로 알림이 오지 않게 한다.
class DeviceRegistrar {
  DeviceRegistrar(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tokenRefresh;
  bool _teacher = false;
  bool _registered = false;

  PushMessaging get _push => _ref.read(pushMessagingProvider);

  Future<void> onSession(SessionState session) async {
    final teacher = session is SignedIn && session.role == Role.teacher;
    if (!teacher) {
      _stop();
      return;
    }
    if (_teacher) return;
    _teacher = true;
    await _registerIfGranted();
  }

  /// 앱이 다시 앞으로 왔을 때. 아직 등록하지 못했으면(실패·뒤늦게 권한 허용) 다시 시도한다.
  Future<void> onResume() async {
    _ref.invalidate(pushPermissionProvider);
    if (_teacher && !_registered) await _registerIfGranted();
  }

  /// 교사 홈 진입 때 부른다. 이미 허용·거부했으면 묻지 않는다.
  Future<void> requestPermissionIfNeeded() async {
    if (!_teacher || !_push.isAvailable) return;
    try {
      if (await _push.permissionStatus() != PushPermission.notDetermined) return;
      if (await _push.requestPermission() == PushPermission.granted) {
        await _register();
      }
    } catch (_) {
      // 기기 알림 서비스 오류(FirebaseException 등) — 앱 사용은 막지 않는다.
    }
    _ref.invalidate(pushPermissionProvider);
  }

  /// 서버에서 이 기기의 알림 등록을 푼다(세션이 살아 있을 때만 가능). 실패는 무시한다(F2 FR-031).
  /// 풀었으므로 앱이 다시 앞으로 오면 다시 등록할 수 있게 해 둔다(탈퇴 실패 등으로 세션이 남는 경우).
  Future<void> unregisterDevice() async {
    final repository = _ref.read(notificationRepositoryProvider);
    _registered = false;
    try {
      await repository.unregisterCurrentDevice();
    } catch (_) {
      // 오프라인이면 서버 해제가 안 된다 — 기기 토큰 폐기([deleteToken])가 이어서 막는다.
    }
  }

  /// 로그아웃·탈퇴로 세션을 끝낼 때 기기 알림 토큰을 폐기한다. 서버 결과와 관계없이 부른다.
  /// 상태를 비워 두므로 다음 교사 로그인에서 새 토큰을 받아 다시 등록한다.
  Future<void> deleteToken() async {
    _stop();
    try {
      await _push.deleteToken();
    } catch (_) {
      // 기기 알림 서비스 오류·오프라인 — 로그아웃은 막지 않는다.
    }
  }

  Future<void> _registerIfGranted() async {
    if (!_push.isAvailable) return;
    try {
      if (await _push.permissionStatus() == PushPermission.granted) {
        await _register();
      }
    } catch (_) {
      // APNs 토큰 없음·Play 서비스 없음 등. 다음 앱 복귀 때 다시 시도한다.
    }
  }

  Future<void> _register() async {
    final token = await _push.getToken();
    if (token == null || !_teacher) return;
    await _send(token);
    _tokenRefresh ??= _push.onTokenRefresh.listen(_send);
  }

  Future<void> _send(String token) async {
    if (!_teacher) return;
    try {
      await _ref
          .read(notificationRepositoryProvider)
          .registerDevice(
            token: token,
            platform: _push.platform == 'IOS'
                ? DevicePlatform.ios
                : DevicePlatform.android,
          );
      _registered = true;
    } on AppException {
      // 실패는 화면에 보이지 않고 다음 계기(토큰 갱신·앱 복귀)에 다시 시도한다.
      _registered = false;
    }
  }

  void _stop() {
    _teacher = false;
    _registered = false;
    _tokenRefresh?.cancel();
    _tokenRefresh = null;
  }
}

/// 앱 루트에서 watch 해 세션 변화를 구독한다.
final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  final registrar = DeviceRegistrar(ref);
  ref.listen(
    sessionControllerProvider,
    (_, next) => registrar.onSession(next),
    fireImmediately: true,
  );
  ref.onDispose(registrar._stop);
  return registrar;
});

/// 기기 알림 권한(설정 화면 안내용). 알림 기능이 없는 실행이면 null.
final pushPermissionProvider = FutureProvider.autoDispose<PushPermission?>((ref) {
  final push = ref.watch(pushMessagingProvider);
  return push.isAvailable ? push.permissionStatus() : Future.value(null);
});
