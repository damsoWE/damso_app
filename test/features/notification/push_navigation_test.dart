import 'package:damso_app/core/push/push_messaging.dart';
import 'package:damso_app/core/push/push_messaging_provider.dart';
import 'package:damso_app/features/notification/data/mock_notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_push.dart';
import '../../helpers/test_app.dart';

const _urgentId = 'a1000000-0000-4000-8000-000000000001'; // mock 의 확인 전 긴급 문의

PushData _urgent() => const PushData(kind: PushKind.urgent, inquiryId: _urgentId);

void main() {
  late FakePush push;
  late MockNotificationRepository notification;

  Widget app() {
    push = FakePush();
    notification = MockNotificationRepository();
    return testApp(
      notification: notification,
      extraOverrides: [pushMessagingProvider.overrideWithValue(push)],
    );
  }

  testWidgets('열린 상태 긴급 수신 → 앱 안 배너, 보기 → 긴급 상세', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');
    expect(notification.registerCalls, 1); // 교사 로그인 → 기기 등록

    push.foreground.add(
      PushMessage(title: '긴급 문의가 도착했습니다', body: '지금 확인해 주세요.', data: _urgent()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('긴급 문의가 도착했습니다'), findsOneWidget);

    await tapText(tester, '보기');
    expect(find.text('(mock) 데모 문의 원문입니다.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // 목록 새로 고침(mock 지연) 마무리
  });

  testWidgets('로그아웃 상태에서 알림으로 열기 → 교사 로그인 뒤 긴급 상세', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    push.opened.add(_urgent());
    await tester.pumpAndSettle();
    await login(tester, 'teacher@damso.test');
    expect(find.text('(mock) 데모 문의 원문입니다.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('로그아웃 상태에서 알림으로 열고 학부모로 로그인하면 버린다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    push.opened.add(_urgent());
    await tester.pumpAndSettle();
    await login(tester, 'parent@damso.test');
    expect(find.text('학부모 홈'), findsOneWidget);
  });

  testWidgets('교사 로그아웃 → 기기 등록 해제 호출', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');
    await tapTab(tester, '마이페이지');
    await tapText(tester, '로그아웃');
    expect(notification.unregisterCalls, 1);
  });

  testWidgets('마이페이지에서 홈·문의 탭으로 돌아오면 교사 목록을 다시 불러온다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');
    expect(find.text('긴급 문의 1건'), findsOneWidget);

    await tapTab(tester, '문의');
    await tester.tap(find.text('긴급 문의').first); // 맨 위(확인 전) 긴급 → 상세(원문 열람)
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapTab(tester, '마이페이지');
    await tapTab(tester, '홈');
    expect(find.text('긴급 문의 1건'), findsNothing);
  });
}
