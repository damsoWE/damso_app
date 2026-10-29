import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/push/push_messaging.dart';
import 'package:damso_app/core/push/push_messaging_provider.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/features/notification/data/mock_notification_repository.dart';
import 'package:damso_app/features/notification/data/notification_repository_provider.dart';
import 'package:damso_app/features/notification/domain/models.dart';
import 'package:damso_app/features/notification/presentation/device_registrar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_push.dart';

class _FailingUnregister extends MockNotificationRepository {
  @override
  Future<void> unregisterCurrentDevice() async {
    unregisterCalls++;
    throw const AppException(message: '실패');
  }
}

void main() {
  late FakePush push;
  late MockNotificationRepository repo;
  late ProviderContainer container;

  void create({MockNotificationRepository? notification}) {
    FlutterSecureStorage.setMockInitialValues({});
    push = FakePush();
    repo = notification ?? MockNotificationRepository();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        pushMessagingProvider.overrideWithValue(push),
        notificationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    container.read(deviceRegistrarProvider);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  SessionController session() => container.read(sessionControllerProvider.notifier);

  setUp(create);

  test('교사 로그인 + 권한 허용 → 등록 1회, 토큰이 바뀌면 다시 등록', () async {
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 1);
    expect(repo.registeredToken, 'token-1');

    push.tokenRefresh.add('token-2');
    await settle();
    expect(repo.registerCalls, 2);
    expect(repo.registeredToken, 'token-2');
  });

  test('학부모 로그인 + 권한 허용 → 등록 1회(specs/007 R8)', () async {
    session().signIn(Role.parent);
    await settle();
    expect(repo.registerCalls, 1);
    expect(repo.registeredToken, 'token-1');
  });

  test('관리자는 등록하지 않는다', () async {
    session().signIn(Role.superAdmin);
    await settle();
    expect(repo.registerCalls, 0);
  });

  test('학부모 로그아웃 → 서버 해제와 기기 토큰 폐기, 토큰 갱신을 더 보내지 않는다', () async {
    session().signIn(Role.parent);
    await settle();
    final registrar = container.read(deviceRegistrarProvider);
    await registrar.unregisterDevice();
    await registrar.deleteToken();
    expect(repo.unregisterCalls, 1);
    expect(push.deleteTokenCalls, 1);

    push.tokenRefresh.add('token-2');
    await settle();
    expect(repo.registerCalls, 1);
  });

  test('권한 거부면 등록하지 않고, 교사 홈에서도 다시 묻지 않는다', () async {
    push.permission = PushPermission.denied;
    session().signIn(Role.teacher);
    await settle();
    await container.read(deviceRegistrarProvider).requestPermissionIfNeeded();
    expect(repo.registerCalls, 0);
    expect(push.requestCalls, 0);
  });

  test('"정하지 않음"이면 교사 홈에서 한 번 묻고, 허용하면 등록', () async {
    push.permission = PushPermission.notDetermined;
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 0);

    final registrar = container.read(deviceRegistrarProvider);
    await registrar.requestPermissionIfNeeded();
    expect(push.requestCalls, 1);
    expect(repo.registerCalls, 1);

    await registrar.requestPermissionIfNeeded(); // 이미 정했으므로 다시 묻지 않음
    expect(push.requestCalls, 1);
  });

  test('로그아웃하면 토큰 갱신을 더 보내지 않는다', () async {
    session().signIn(Role.teacher);
    await settle();
    await session().signOut();
    await settle();
    push.tokenRefresh.add('token-2');
    await settle();
    expect(repo.registerCalls, 1);
  });

  test('플랫폼 값', () {
    expect(DevicePlatform.android.serverValue, 'ANDROID');
    expect(DevicePlatform.ios.serverValue, 'IOS');
  });

  test('해제 실패는 무시된다(로그아웃을 막지 않음)', () async {
    create(notification: _FailingUnregister());
    await expectLater(
      repo.unregisterCurrentDevice().catchError((Object _) {}),
      completes,
    );
  });

  test('토큰 받기 오류는 잡고, 앱이 다시 앞으로 오면 다시 등록한다', () async {
    push.tokenError = StateError('apns-token-not-set');
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 0);

    push.tokenError = null;
    await container.read(deviceRegistrarProvider).onResume();
    expect(repo.registerCalls, 1);
    await container.read(deviceRegistrarProvider).onResume(); // 이미 등록됨
    expect(repo.registerCalls, 1);
  });

  test('로그인 때 거부였다가 기기 설정에서 켜면 앱 복귀 때 등록', () async {
    push.permission = PushPermission.denied;
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 0);
    push.permission = PushPermission.granted;
    await container.read(deviceRegistrarProvider).onResume();
    expect(repo.registerCalls, 1);
  });

  test('기기 토큰을 폐기하면 토큰 갱신을 더 보내지 않고, 다음 교사 로그인에서 다시 등록한다', () async {
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 1);

    await container.read(deviceRegistrarProvider).deleteToken();
    expect(push.deleteTokenCalls, 1);
    push.tokenRefresh.add('token-2');
    await settle();
    expect(repo.registerCalls, 1);

    await session().signOut();
    push.token = 'token-3';
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 2);
    expect(repo.registeredToken, 'token-3');
  });

  test('서버 해제가 실패해도 예외 없이 끝나고, 앱이 다시 앞으로 오면 다시 등록한다', () async {
    create(notification: _FailingUnregister());
    session().signIn(Role.teacher);
    await settle();
    expect(repo.registerCalls, 1);

    final registrar = container.read(deviceRegistrarProvider);
    await registrar.unregisterDevice();
    expect(repo.unregisterCalls, 1);
    await registrar.onResume();
    expect(repo.registerCalls, 2);
  });
}
