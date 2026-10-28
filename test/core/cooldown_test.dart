import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/core/widgets/cooldown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRemaining', () {
    test('초·분·시간', () {
      expect(formatRemaining(const Duration(seconds: 9)), '9초');
      expect(formatRemaining(const Duration(seconds: 600)), '10분 0초');
      expect(formatRemaining(const Duration(seconds: 3599)), '59분 59초');
      expect(formatRemaining(const Duration(hours: 1)), '1시간');
      expect(formatRemaining(const Duration(seconds: 3661)), '1시간 1분 1초');
      expect(formatRemaining(const Duration(seconds: -1)), '0초');
    });
  });

  group('CooldownTimer', () {
    var now = DateTime(2026, 10, 28, 12);
    late CooldownTimer timer;
    late Cooldown last;

    setUp(() {
      now = DateTime(2026, 10, 28, 12);
      timer = CooldownTimer(now: () => now);
    });
    tearDown(() => timer.cancel());

    testWidgets('앱이 멈춰 틱이 빠지면 실제 시각으로 남은 시간을 맞춘다', (tester) async {
      timer.start(const Duration(hours: 1), (c) => last = c);
      expect(last.remaining, const Duration(hours: 1));

      now = now.add(const Duration(minutes: 20)); // 백그라운드 20분, 틱 없음
      await tester.pump(const Duration(seconds: 1));
      expect(last.remaining, const Duration(minutes: 40));

      await tester.pump(const Duration(seconds: 1));
      expect(last.remaining, const Duration(minutes: 39, seconds: 59));
      timer.cancel(); // testWidgets 는 끝나기 전에 Timer 가 남아 있으면 실패한다
    });

    testWidgets('실제 시각으로 끝났으면 바로 연다', (tester) async {
      timer.start(const Duration(seconds: 30), (c) => last = c);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(last, Cooldown.none);
    });

    test('남은 시간이 없으면 대기 없이 연다', () {
      timer.start(null, (c) => last = c);
      expect(last, Cooldown.none);
    });

    test('startIfLimited 는 TOO_MANY_ATTEMPTS 만 대기를 시작한다', () {
      last = Cooldown.none;
      const other = AppException(message: 'x', code: ErrorCodes.invalidInput);
      expect(timer.startIfLimited(other, (c) => last = c), isFalse);
      expect(last.isActive, isFalse);

      const limited = AppException(
        message: 'x',
        code: ErrorCodes.tooManyAttempts,
        retryAfter: Duration(seconds: 5),
      );
      expect(timer.startIfLimited(limited, (c) => last = c), isTrue);
      expect(last.remaining, const Duration(seconds: 5));
    });
  });
}
