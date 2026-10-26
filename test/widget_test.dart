import 'package:flutter_test/flutter_test.dart';

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
}
