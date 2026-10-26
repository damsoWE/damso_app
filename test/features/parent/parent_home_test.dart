import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 화면의 모든 글자에 '@'(이메일)가 없는지.
void expectNoEmail(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
  expect(texts.where((t) => t.contains('@')), isEmpty);
}

void main() {
  testWidgets('자녀·담임 공개 프로필을 보고, 담임 없는 자녀는 안내가 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');

    expect(find.text('김하나'), findsOneWidget);
    expect(find.text('3학년 2반'), findsOneWidget);
    expect(find.text('이담임'), findsOneWidget);
    expect(find.text('아이들과 천천히 이야기 나누는 담임입니다.'), findsOneWidget);
    expectNoEmail(tester); // FR-038, SC-005

    await tapText(tester, '김하나'); // 자녀 선택(F2-1a)
    expect(find.text('자녀 선택'), findsWidgets);
    await tapText(tester, '김두리');

    expect(find.text('학부모 홈'), findsOneWidget);
    expect(find.text('김두리'), findsOneWidget);
    expect(find.text('담임 선생님이 아직 연결되지 않았습니다.'), findsOneWidget);
  });

  testWidgets('자녀가 없으면 자녀 추가를 안내하고, 교사 코드는 같은 실패 안내', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'newparent@damso.test');

    expect(find.text('연결된 자녀가 없습니다.'), findsOneWidget);
    await tapText(tester, '초대코드로 자녀 추가');
    await enterField(tester, '초대 코드', 'TEACHERCD2');
    await tapText(tester, '코드 확인');
    expect(find.text('코드를 확인해 주세요.'), findsOneWidget);

    await enterField(tester, '초대 코드', 'PARENTCDE2');
    await tapText(tester, '코드 확인');
    expect(find.text('학부모 홈'), findsOneWidget);
    expect(find.text('김새봄'), findsOneWidget);
  });
}
