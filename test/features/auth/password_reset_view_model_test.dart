import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/core/widgets/cooldown.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/auth/presentation/password_reset/password_reset_view_model.dart';
import 'package:damso_app/features/me/data/me_repository_provider.dart';
import 'package:damso_app/features/me/data/mock_me_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 코드 요청 횟수를 세고, [limit] 이 있으면 그 남은 시간으로 429 를 낸다.
class _CountingAuth extends MockAuthRepository {
  _CountingAuth(super.tokens);

  int resetCalls = 0;
  Duration? limit;

  @override
  Future<void> requestPasswordReset(String email) {
    resetCalls++;
    final retryAfter = limit;
    if (retryAfter != null) {
      throw AppException(
        message: '잠시 후 다시 시도해 주세요.',
        code: ErrorCodes.tooManyAttempts,
        statusCode: 429,
        retryAfter: retryAfter,
      );
    }
    return super.requestPasswordReset(email);
  }
}

void main() {
  late ProviderContainer container;
  late _CountingAuth auth;

  PasswordResetViewModel vm() =>
      container.read(passwordResetViewModelProvider.notifier);
  PasswordResetState state() => container.read(passwordResetViewModelProvider);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    final tokens = TokenStore()..accessToken = 'mock:parent'; // parent@damso.test
    auth = _CountingAuth(tokens);
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        meRepositoryProvider.overrideWithValue(MockMeRepository(tokens)),
      ],
    );
    container.listen(passwordResetViewModelProvider, (_, _) {});
  });

  Future<void> toCode([String email = 'anyone@damso.test']) async {
    expect(await vm().requestReset(email), isTrue);
  }

  test('어떤 이메일이든 같은 안내와 함께 코드 입력으로 (FR-023)', () async {
    await toCode();
    expect(state().step, ResetStep.codeEntry);
    expect(state().notice, '입력한 이메일로 안내를 보냈습니다.');
  });

  test('맞는 코드 → 새 비밀번호, 틀린 코드 → 안내', () async {
    await toCode();
    expect(await vm().verifyCode('111111'), isFalse);
    expect(state().step, ResetStep.codeEntry);
    expect(state().errorMessage, isNotNull);

    expect(await vm().verifyCode('123456'), isTrue);
    expect(state().step, ResetStep.newPassword);
  });

  test('잠금 → C-3c, 코드 다시 받기 → 코드 입력', () async {
    await toCode();
    await vm().verifyCode('000000');
    expect(state().step, ResetStep.expiredOrLocked);
    await vm().resendCode();
    expect(state().step, ResetStep.codeEntry);
  });

  test('로그인한 내 계정을 재설정하면 이 기기도 로그아웃 (FR-025)', () async {
    container.read(sessionControllerProvider.notifier).signIn(Role.parent);
    await toCode('Parent@damso.test');
    await vm().verifyCode('123456');
    expect(await vm().confirm('abcd1234'), isTrue);
    expect(state().step, ResetStep.done);
    expect(container.read(sessionControllerProvider), const SignedOut());
  });

  test('다른 계정을 재설정하면 지금 로그인한 세션은 유지된다', () async {
    container.read(sessionControllerProvider.notifier).signIn(Role.parent);
    await toCode('other@damso.test');
    await vm().verifyCode('123456');
    expect(await vm().confirm('abcd1234'), isTrue);
    expect(state().step, ResetStep.done);
    expect(container.read(sessionControllerProvider), const SignedIn(Role.parent));
  });

  test('로그아웃 상태에서는 세션을 건드리지 않는다', () async {
    await container.read(sessionControllerProvider.notifier).signOut();
    await toCode();
    await vm().verifyCode('123456');
    expect(await vm().confirm('abcd1234'), isTrue);
    expect(container.read(sessionControllerProvider), const SignedOut());
  });

  test('정책에 맞지 않는 새 비밀번호는 보내지 않는다', () async {
    await toCode();
    await vm().verifyCode('123456');
    expect(await vm().confirm('abcdefgh'), isFalse);
    expect(state().fieldErrors['newPassword'], isNotNull);
    expect(state().step, ResetStep.newPassword);
  });

  group('코드 메일 발송 대기(429, api-v0.8)', () {
    test('이메일 화면에 남아 서버 문구와 남은 시간을 보이고, 대기 중에는 보내지 않는다', () async {
      expect(await vm().requestReset('wait@damso.test'), isFalse);
      expect(state().step, ResetStep.emailEntry);
      expect(state().errorMessage, '잠시 후 다시 시도해 주세요.');
      expect(state().cooldown.remaining, const Duration(seconds: 30));

      expect(await vm().requestReset(' Wait@damso.test'), isFalse);
      expect(auth.resetCalls, 1);
    });

    test('대기는 걸린 이메일에만 — 다른 이메일로 바꾸면 풀리고 요청할 수 있다', () async {
      await vm().requestReset('wait@damso.test');
      vm().emailChanged('wait@damso.tes');
      expect(state().cooldown.isActive, isFalse);
      expect(state().errorMessage, isNull);

      expect(await vm().requestReset('anyone@damso.test'), isTrue);
      expect(auth.resetCalls, 2);
    });

    test('입력을 거치지 않고 다른 이메일로 요청해도 막지 않는다', () async {
      await vm().requestReset('wait@damso.test');
      expect(await vm().requestReset('anyone@damso.test'), isTrue);
      expect(state().cooldown.isActive, isFalse);
    });

    test('남은 시간이 없는 429 는 서버 문구만 보이고 막지 않는다', () async {
      auth.limit = Duration.zero; // Retry-After 없음과 같다(0 이하는 무시)
      expect(await vm().requestReset('anyone@damso.test'), isFalse);
      expect(state().errorMessage, '잠시 후 다시 시도해 주세요.');
      expect(state().cooldown, Cooldown.none);

      auth.limit = null;
      expect(await vm().requestReset('anyone@damso.test'), isTrue);
    });

    test('C-3c 코드 다시 받기가 대기에 걸리면 C-3c 에 남아 남은 시간을 보인다', () async {
      await toCode();
      await vm().verifyCode('000000');
      auth.limit = const Duration(seconds: 45);
      await vm().resendCode();
      expect(state().step, ResetStep.expiredOrLocked);
      expect(state().cooldown.remaining, const Duration(seconds: 45));

      await vm().resendCode();
      expect(auth.resetCalls, 2);
    });

    test('남은 시간이 1시간(3600초)이어도 그대로 보인다', () async {
      auth.limit = const Duration(seconds: 3600);
      await vm().requestReset('anyone@damso.test');
      expect(state().cooldown.remaining, const Duration(hours: 1));
      expect(formatRemaining(state().cooldown.remaining), '1시간');
    });
  });

  testWidgets('대기 남은 시간이 1초씩 줄고 0이 되면 다시 요청할 수 있다', (tester) async {
    auth.limit = const Duration(seconds: 2);
    await vm().requestReset('anyone@damso.test');
    expect(state().cooldown.remaining, const Duration(seconds: 2));

    await tester.pump(const Duration(seconds: 1));
    expect(state().cooldown.remaining, const Duration(seconds: 1));

    await tester.pump(const Duration(seconds: 1));
    expect(state().cooldown.isActive, isFalse);

    auth.limit = null;
    final retry = vm().requestReset('anyone@damso.test');
    await tester.pump(const Duration(milliseconds: 300));
    expect(await retry, isTrue);
    expect(state().step, ResetStep.codeEntry);
    expect(auth.resetCalls, 2);
  });
}
