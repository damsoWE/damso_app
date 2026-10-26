import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/auth/presentation/splash_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _RestoreAuth extends MockAuthRepository {
  _RestoreAuth(this._restore) : super(TokenStore());

  final Future<Role?> Function() _restore;

  @override
  Future<Role?> restoreSession() => _restore();
}

AppException _status(int statusCode) =>
    AppException(message: '안내', statusCode: statusCode);

void main() {
  Future<SessionState> restore(Future<Role?> Function() outcome) async {
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'rt'});
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(_RestoreAuth(outcome)),
      ],
    );
    await container.read(splashViewModelProvider.notifier).restore();
    return container.read(sessionControllerProvider);
  }

  test('갱신이 401·400 으로 거절되면 로그인 화면(만료)', () async {
    for (final status in [401, 400]) {
      expect(
        await restore(() async => throw _status(status)),
        const SignedOut(sessionExpired: true),
        reason: '$status',
      );
    }
  });

  test('5xx·네트워크 오류면 연결 불가(다시 시도)', () async {
    expect(
      await restore(() async => throw _status(503)),
      isA<SessionUnreachable>(),
    );
    expect(
      await restore(
        () async => throw const AppException(
          message: AppException.networkMessage,
          isNetworkError: true,
        ),
      ),
      isA<SessionUnreachable>(),
    );
  });

  test('보안 저장소·응답 형식 오류는 무한 로딩 대신 시작 화면으로', () async {
    expect(
      await restore(() async => throw PlatformException(code: 'storage')),
      const SignedOut(),
    );
    expect(
      await restore(() async => throw TypeError()),
      const SignedOut(),
    );
  });
}
