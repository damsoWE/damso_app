import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('시작 → 로그인하면 학부모 홈이 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');
    expect(find.text('학부모 홈'), findsOneWidget);
  });

  testWidgets('로그인 실패 시 서버 message 만 보여 준다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test', password: 'wrong');
    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
    expect(find.text('학부모 홈'), findsNothing);
  });

  testWidgets('기존 뼈대 문의 목록은 로그인 후 그대로 동작한다 (FR-013)', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    GoRouter.of(tester.element(find.text('교사 홈'))).go('/inquiries');
    await tester.pumpAndSettle();
    expect(find.text('긴급 문의 예시'), findsOneWidget);
    expect(find.text('원문 확인 필요'), findsOneWidget);
  });
}
