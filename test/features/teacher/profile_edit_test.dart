import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Future<void> openMyPage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('마이페이지'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('소개 61자는 저장할 수 없고, 저장한 값은 다시 열어도 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await openMyPage(tester);
    await tapText(tester, '공개 프로필');

    await enterField(tester, '소개', '가' * 61);
    expect(find.text('61/60'), findsOneWidget);
    expect(isEnabled(tester, '저장'), isFalse);

    await enterField(tester, '표시 이름', '김선생');
    await enterField(tester, '소개', '가' * 60);
    expect(find.text('60/60'), findsOneWidget);
    expect(isEnabled(tester, '저장'), isTrue);
    await tapText(tester, '저장');

    expect(find.widgetWithText(AppBar, '마이페이지'), findsOneWidget);
    await tapText(tester, '공개 프로필');
    expect(find.text('김선생'), findsOneWidget);
  });

  testWidgets('연결 현황은 연결됨·미연결만 보이고 학부모 정보는 없다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await openMyPage(tester);
    await tapText(tester, '학부모 연결 현황');

    expect(find.text('3학년 2반'), findsOneWidget);
    expect(find.text('연결됨'), findsOneWidget);
    expect(find.text('미연결'), findsNWidgets(2));
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
    expect(texts.where((t) => t.contains('@')), isEmpty);
  });

  testWidgets('담당 학급이 없으면 서버 안내(403)가 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'noclass@damso.test');
    await openMyPage(tester);
    await tapText(tester, '학부모 연결 현황');

    expect(find.text('권한이 없습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
