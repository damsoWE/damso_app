import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:damso_app/app/app.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_provider.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_repository.dart';

Widget _app() => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(MockAuthRepository()),
    inquiryRepositoryProvider.overrideWithValue(MockInquiryRepository()),
  ],
  child: const DamsoApp(),
);

void main() {
  testWidgets('로그인하면 문의 목록이 보인다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.widgetWithText(TextField, '이메일'), 'a@b.c');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'pw');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('긴급 문의 예시'), findsOneWidget);
    expect(find.text('원문 확인 필요'), findsOneWidget);
  });

  testWidgets('로그인 실패 시 서버 message 만 보여 준다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.widgetWithText(TextField, '이메일'), 'a@b.c');
    await tester.tap(find.text('로그인')); // 비밀번호 비움 → mock 401
    await tester.pumpAndSettle();
    expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
    expect(find.text('긴급 문의 예시'), findsNothing);
  });
}
