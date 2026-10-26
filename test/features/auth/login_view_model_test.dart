import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/auth/domain/models.dart';
import 'package:damso_app/features/auth/presentation/login_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingAuth extends MockAuthRepository {
  _CountingAuth() : super(TokenStore());

  int loginCalls = 0;

  @override
  Future<AuthResult> login({required String email, required String password}) {
    loginCalls++;
    return super.login(email: email, password: password);
  }
}

void main() {
  late ProviderContainer container;
  late _CountingAuth auth;

  LoginViewModel vm() => container.read(loginViewModelProvider.notifier);
  LoginState state() => container.read(loginViewModelProvider);

  void createContainer() {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _CountingAuth();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    container.listen(loginViewModelProvider, (_, _) {});
  }

  group('ProviderContainer', () {
    setUp(createContainer);

    test('역할 3종 계정은 각 역할로 로그인된다', () async {
      const accounts = {
        'parent@damso.test': Role.parent,
        'teacher@damso.test': Role.teacher,
        'admin@damso.test': Role.superAdmin,
      };
      for (final MapEntry(key: email, value: role) in accounts.entries) {
        await vm().login(email: email, password: 'damso1234');
        expect(container.read(sessionControllerProvider), SignedIn(role));
      }
    });

    test('틀린 비밀번호와 없는 이메일은 같은 안내 (FR-020)', () async {
      await vm().login(email: 'parent@damso.test', password: 'wrong');
      final wrongPassword = state().errorMessage;
      await vm().login(email: 'nobody@damso.test', password: 'damso1234');
      expect(wrongPassword, isNotNull);
      expect(state().errorMessage, wrongPassword);
      expect(container.read(sessionControllerProvider), isNot(isA<SignedIn>()));
    });

    test('대기 중에는 서버에 보내지 않는다', () async {
      await vm().login(email: 'wait@damso.test', password: 'x');
      expect(state().cooldown.isActive, isTrue);
      expect(auth.loginCalls, 1);
      await vm().login(email: 'parent@damso.test', password: 'damso1234');
      expect(auth.loginCalls, 1);
    });

    test('형식이 틀리면 서버에 보내지 않고 필드 안내', () async {
      await vm().login(email: 'not-an-email', password: '');
      expect(auth.loginCalls, 0);
      expect(state().fieldErrors.keys, containsAll(['email', 'password']));
    });
  });

  testWidgets('대기 남은 시간이 1초씩 줄고 0이 되면 다시 시도할 수 있다 (SC-008)', (
    tester,
  ) async {
    createContainer();
    final pending = vm().login(email: 'wait@damso.test', password: 'x');
    await tester.pump(const Duration(milliseconds: 300));
    await pending;
    expect(state().cooldown.remaining, const Duration(seconds: 30));

    await tester.pump(const Duration(seconds: 1));
    expect(state().cooldown.remaining, const Duration(seconds: 29));

    await tester.pump(const Duration(seconds: 29));
    expect(state().cooldown.isActive, isFalse);

    final retry = vm().login(email: 'parent@damso.test', password: 'damso1234');
    await tester.pump(const Duration(milliseconds: 300));
    await retry;
    expect(auth.loginCalls, 2);
    expect(container.read(sessionControllerProvider), const SignedIn(Role.parent));
  });
}
