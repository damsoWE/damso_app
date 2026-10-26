import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Future<void> openMyPage(WidgetTester tester) async {
  await tester.tap(find.byTooltip('마이페이지'));
  await tester.pumpAndSettle();
}

/// quickstart 시나리오 19·20 (US7).
void main() {
  testWidgets('이름을 바꾸고, 로그아웃하면 시작 화면으로', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');
    await openMyPage(tester);

    expect(find.text('김학부모 · 학부모'), findsOneWidget);
    expect(find.text('parent@damso.test'), findsOneWidget); // 본인 이메일만
    await tapText(tester, '계정 정보');
    await enterField(tester, '이름', '김보호자');
    await tapText(tester, '저장');
    expect(find.text('저장했습니다.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('김보호자 · 학부모'), findsOneWidget);

    await tapText(tester, '로그아웃');
    expect(find.text('초대코드로 가입하기'), findsOneWidget); // C-0
  });

  testWidgets('탈퇴: 틀린 비밀번호는 안내, 맞는 비밀번호는 시작 화면으로', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await openMyPage(tester);
    expect(find.text('담당 3학년 2반'), findsOneWidget);
    await tapText(tester, '회원 탈퇴');

    await enterField(tester, '현재 비밀번호', 'wrong');
    await tapText(tester, '탈퇴하기');
    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);

    await enterField(tester, '현재 비밀번호', 'damso1234');
    await tapText(tester, '탈퇴하기');
    expect(find.text('초대코드로 가입하기'), findsOneWidget);
  });

  testWidgets('관리자 마이페이지에는 탈퇴 메뉴가 없다 (FR-039)', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'admin@damso.test');
    await openMyPage(tester);

    expect(find.text('학교 관리자 · 관리자'), findsOneWidget);
    expect(find.text('담소 이용 안내'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsNothing);
  });
}
