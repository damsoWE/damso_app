import 'package:damso_app/core/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('초대 코드', () {
    test('공백 제거·대문자 변환 후 통과', () {
      expect(normalizeInviteCode(' parentcde2 '), 'PARENTCDE2');
      expect(normalizeInviteCode('pare ntcd e2'), 'PARENTCDE2');
      expect(validateInviteCode(' parentcde2 '), isNull);
    });

    test('길이·허용 문자 위반은 실패', () {
      expect(validateInviteCode('PARENTCD2'), isNotNull); // 9자
      expect(validateInviteCode('PARENTCDE22'), isNotNull); // 11자
      for (final bad in ['0', 'O', '1', 'I', 'L']) {
        expect(validateInviteCode('PARENTCDE$bad'), isNotNull, reason: bad);
      }
      expect(validateInviteCode(''), isNotNull);
    });
  });

  group('이름', () {
    test('빈 값·공백만은 실패', () {
      expect(validateName(''), isNotNull);
      expect(validateName('   '), isNotNull);
    });

    test('20자 통과, 21자 실패, 이모지는 1자', () {
      expect(validateName('가' * 20), isNull);
      expect(validateName('가' * 21), isNotNull);
      expect(validateName('${'가' * 19}😀'), isNull);
    });
  });

  group('이메일', () {
    test('형식', () {
      expect(validateEmail('a@b.c'), isNull);
      expect(validateEmail('  a@b.c  '), isNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail(''), isNotNull);
    });

    test('254자 초과는 실패', () {
      final local = 'a' * 64;
      final domain = '${'b' * 185}.com'; // 64 + 1 + 189 = 254
      expect(validateEmail('$local@$domain'), isNull);
      expect(validateEmail('$local@b$domain'), isNotNull);
    });
  });

  group('비밀번호', () {
    test('가입·재설정: 영문+숫자 8~64자', () {
      expect(validateNewPassword('abcdefgh'), isNotNull);
      expect(validateNewPassword('12345678'), isNotNull);
      expect(validateNewPassword('abcd1234'), isNull);
      expect(validateNewPassword('abc1234'), isNotNull); // 7자
      expect(validateNewPassword('a1${'x' * 62}'), isNull); // 64자
      expect(validateNewPassword('a1${'x' * 63}'), isNotNull); // 65자
    });

    test('로그인·탈퇴 확인: 1~64자', () {
      expect(validateCurrentPassword(''), isNotNull);
      expect(validateCurrentPassword('x' * 64), isNull);
      expect(validateCurrentPassword('x' * 65), isNotNull);
    });
  });

  group('6자리 코드', () {
    test('공백 제거 후 숫자 6자리', () {
      expect(normalizeSixDigitCode(' 123456'), '123456');
      expect(validateSixDigitCode(' 123456'), isNull);
      expect(validateSixDigitCode('12345'), isNotNull);
      expect(validateSixDigitCode('12345a'), isNotNull);
    });
  });
}
