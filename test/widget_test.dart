import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:damso_app/app/app.dart';
import 'package:damso_app/mock/mock_overrides.dart';

void main() {
  testWidgets('mock 으로 로그인 후 문의 목록이 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: mockOverrides, child: const DamsoApp()),
    );
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('긴급 문의 예시'), findsOneWidget);
  });
}
