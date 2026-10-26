import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/auth/domain/models.dart';
import 'package:damso_app/features/auth/presentation/signup/signup_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  SignupViewModel vm() => container.read(signupViewModelProvider.notifier);
  SignupState state() => container.read(signupViewModelProvider);

  Future<void> toAccount([String code = 'PARENTCDE2']) async {
    expect(await vm().submitCode(code), SignupOutcome.next);
  }

  Future<void> toVerifying({String email = 'new@damso.test'}) async {
    await toAccount();
    expect(
      await vm().submitAccount(
        name: '김보호',
        email: email,
        password: 'abcd1234',
        termsAgreed: true,
      ),
      SignupOutcome.next,
    );
  }

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
    container.listen(signupViewModelProvider, (_, _) {}); // autoDispose 유지
  });

  group('초대 코드 (F1-1)', () {
    test('학부모 코드 → 계정 정보(학부모)', () async {
      await toAccount('parentcde2');
      expect(state().step, SignupStep.accountForm);
      expect(state().inviteRole, InviteRole.parent);
      expect(state().inviteCode, 'PARENTCDE2');
    });

    test('교사 코드 → 계정 정보(교사)', () async {
      await toAccount('TEACHERCD2');
      expect(state().inviteRole, InviteRole.teacher);
    });

    test('없는 코드 → 사유 구분 없는 안내 (F1-2)', () async {
      expect(await vm().submitCode('AAAAAAAAAA'), SignupOutcome.stay);
      expect(state().step, SignupStep.codeEntry);
      expect(state().errorMessage, '코드를 확인해 주세요.');
    });

    test('잠금 → 600초 대기, 대기 중에는 제출 안 됨 (F1-2b)', () async {
      await vm().submitCode('ZZZZZZZZZZ');
      expect(state().attemptCooldown.isActive, isTrue);
      expect(state().attemptCooldown.remaining, const Duration(seconds: 600));
      expect(await vm().submitCode('PARENTCDE2'), SignupOutcome.stay);
      expect(state().step, SignupStep.codeEntry);
    });
  });

  group('계정 정보 (F1-3)', () {
    test('서버 필드 오류를 필드별로 담는다', () async {
      await toAccount();
      final outcome = await vm().submitAccount(
        name: '김보호',
        email: 'invalid@damso.test',
        password: 'abcd1234',
        termsAgreed: true,
      );
      expect(outcome, SignupOutcome.stay);
      expect(state().step, SignupStep.accountForm);
      expect(state().fieldErrors['email'], isNotNull);
    });

    test('약관 미동의는 서버에 보내지 않는다', () async {
      await toAccount();
      final outcome = await vm().submitAccount(
        name: '김보호',
        email: 'new@damso.test',
        password: 'abcd1234',
        termsAgreed: false,
      );
      expect(outcome, SignupOutcome.stay);
      expect(state().isSubmitting, isFalse);
    });

    test('정상 → 인증 단계, 유효 시간 10분', () async {
      await toVerifying();
      expect(state().step, SignupStep.verifying);
      expect(state().pending?.codeExpiresIn, const Duration(minutes: 10));
    });
  });

  group('이메일 인증 (C-2)', () {
    test('123456 → 가입 직후 로그인 상태', () async {
      await toVerifying();
      expect(await vm().verify('123456'), SignupOutcome.next);
      expect(
        container.read(sessionControllerProvider),
        const SignedIn(Role.parent, justSignedUp: true),
      );
    });

    test('999999 → 초대 코드 입력으로, 이름·이메일 유지', () async {
      await toVerifying();
      expect(await vm().verify('999999'), SignupOutcome.backToCode);
      expect(state().step, SignupStep.codeEntry);
      expect(state().errorMessage, '코드를 확인해 주세요.');
      expect(state().name, '김보호');
      expect(state().email, 'new@damso.test');
      expect(state().pending, isNull);
    });

    test('틀린 코드 → 인증 단계에 안내', () async {
      await toVerifying();
      expect(await vm().verify('111111'), SignupOutcome.stay);
      expect(state().step, SignupStep.verifying);
      expect(state().errorMessage, isNotNull);
    });

    test('000000 → 인증 버튼 잠금, 재발송은 별도', () async {
      await toVerifying();
      await vm().verify('000000');
      expect(state().attemptCooldown.remaining, const Duration(seconds: 600));
      expect(state().resendCooldown.isActive, isFalse);
    });

    test('재발송 → 60초 재발송 잠금', () async {
      await toVerifying();
      await vm().resend();
      expect(state().resendCooldown.remaining, const Duration(seconds: 60));
      expect(state().notice, isNotNull);
      expect(state().attemptCooldown.isActive, isFalse);
    });
  });
}
