import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/presentation/dial_launcher.dart';
import 'package:damso_app/features/inquiry/presentation/parent/urgent_notice_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDialer implements DialLauncher {
  _FakeDialer({this.available = true});

  final bool available;
  final dialed = <String>[];

  @override
  Future<bool> canDial() async => available;

  @override
  Future<void> dial(String number) async => dialed.add(number);
}

Future<void> pumpView(
  WidgetTester tester,
  List<Hotline> hotlines,
  DialLauncher dialer,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dialLauncherProvider.overrideWithValue(dialer)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UrgentNoticeView(hotlines: hotlines)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const cases = {
    'F2-3c 자해': ([Hotline.suicidePrevention], ['109']),
    'F2-3d 학대': ([Hotline.childAbuse], ['112']),
    'F2-3 그 밖의 안전': (<Hotline>[], <String>[]),
    'F2-3b 분류 안 됨': ([Hotline.childAbuse, Hotline.suicidePrevention], ['112', '109']),
  };

  for (final MapEntry(key: name, value: (hotlines, numbers)) in cases.entries) {
    testWidgets('$name: 바로 전달 안내와 맞는 번호 버튼만', (tester) async {
      final dialer = _FakeDialer();
      await pumpView(tester, hotlines, dialer);

      expect(find.text('선생님께 바로 전달했어요.'), findsOneWidget);
      for (final n in ['109', '112']) {
        expect(
          find.text('$n로 전화하기'),
          numbers.contains(n) ? findsOneWidget : findsNothing,
          reason: n,
        );
      }
      for (final n in numbers) {
        await tester.tap(find.text('$n로 전화하기'));
      }
      expect(dialer.dialed, numbers); // 다이얼 화면만 연다(통화는 사용자가)
    });
  }

  testWidgets('전화 걸기 화면을 열 수 없는 기기면 번호는 보이고 버튼은 비활성', (tester) async {
    final dialer = _FakeDialer(available: false);
    await pumpView(tester, const [Hotline.suicidePrevention], dialer);

    expect(find.text('자살예방 상담전화 109'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '109로 전화하기'),
    );
    expect(button.onPressed, isNull);
  });
}
