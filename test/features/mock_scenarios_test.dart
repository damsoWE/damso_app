import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

SessionState sessionOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(sessionControllerProvider);

/// US8: 서버 없이 mock 만으로 정상·오류·잠금·권한 없음·세션 만료를 재현한다(FR-012, SC-007).
void main() {
  testWidgets('세션 만료(갱신 거부) → 로그인 화면, 보호 화면으로 다시 가도 로그인 화면', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'expired@damso.test');

    expect(find.text('학부모 홈'), findsNothing);
    expect(find.widgetWithText(TextField, '이메일'), findsOneWidget); // C-1
    expect(sessionOf(tester), const SignedOut(sessionExpired: true));

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/parent');
    await tester.pumpAndSettle();
    expect(find.text('학부모 홈'), findsNothing);
    expect(find.widgetWithText(TextField, '이메일'), findsOneWidget);
  });

  testWidgets('접근 권한 만료 → 갱신 → 재시도 성공은 오류 없이 홈을 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'refresh@damso.test');

    expect(find.text('학부모 홈'), findsOneWidget);
    expect(find.text('김하나'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(sessionOf(tester), const SignedIn(Role.parent));
  });

  testWidgets('담당 학급이 없는 교사는 권한 없음 안내를 본다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'noclass@damso.test');
    await tester.tap(find.byTooltip('마이페이지'));
    await tester.pumpAndSettle();
    await tapText(tester, '학부모 연결 현황');
    expect(find.text('권한이 없습니다.'), findsOneWidget);
  });

  testWidgets('로그인 대기는 서버가 준 남은 시간을 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'wait@damso.test', password: 'x');
    expect(find.text('30초 후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(isEnabled(tester, '로그인'), isFalse);

    await tester.pump(const Duration(seconds: 30));
    expect(isEnabled(tester, '로그인'), isTrue);
  });

  testWidgets('초대 코드 잠금은 남은 시간을 보이고 확인 버튼을 막는다', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tapText(tester, '초대코드로 가입하기');
    await enterField(tester, '초대 코드', 'ZZZZZZZZZZ');
    await enterField(tester, '이메일', 'new@damso.test');
    await tapText(tester, '코드 확인');

    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('10분 0초 후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(isEnabled(tester, '코드 확인'), isFalse);
  });
}
