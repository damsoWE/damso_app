import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/auth/presentation/password_reset/password_reset_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  PasswordResetViewModel vm() =>
      container.read(passwordResetViewModelProvider.notifier);
  PasswordResetState state() => container.read(passwordResetViewModelProvider);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(TokenStore()),
        ),
      ],
    );
    container.listen(passwordResetViewModelProvider, (_, _) {});
  });

  Future<void> toCode() async {
    expect(await vm().requestReset('anyone@damso.test'), isTrue);
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

  test('로그인 상태에서 완료하면 이 기기도 로그아웃 (FR-025)', () async {
    container.read(sessionControllerProvider.notifier).signIn(Role.parent);
    await toCode();
    await vm().verifyCode('123456');
    expect(await vm().confirm('abcd1234'), isTrue);
    expect(state().step, ResetStep.done);
    expect(container.read(sessionControllerProvider), const SignedOut());
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
}
