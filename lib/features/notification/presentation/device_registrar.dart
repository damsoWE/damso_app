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
/// 해제는 로그아웃 직전 MeViewModel 이 부르고, 세션이 끝나면 서버도 보내지 않는다.
class DeviceRegistrar {
  DeviceRegistrar(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tokenRefresh;
  bool _teacher = false;

  PushMessaging get _push => _ref.read(pushMessagingProvider);

  Future<void> onSession(SessionState session) async {
    final teacher = session is SignedIn && session.role == Role.teacher;
    if (!teacher) {
      _stop();
      return;
    }
    if (_teacher) return;
    _teacher = true;
    if (!_push.isAvailable) return;
    if (await _push.permissionStatus() == PushPermission.granted) {
      await _register();
    }
  }

  /// 교사 홈 진입 때 부른다. 이미 허용·거부했으면 묻지 않는다.
  Future<void> requestPermissionIfNeeded() async {
    if (!_teacher || !_push.isAvailable) return;
    if (await _push.permissionStatus() != PushPermission.notDetermined) return;
    if (await _push.requestPermission() == PushPermission.granted) {
      await _register();
    }
    _ref.invalidate(pushPermissionProvider);
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
    } on AppException {
      // 실패는 화면에 보이지 않고 다음 계기(토큰 갱신·다음 로그인)에 다시 시도한다.
    }
  }

  void _stop() {
    _teacher = false;
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
