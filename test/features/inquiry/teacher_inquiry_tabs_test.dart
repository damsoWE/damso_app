import 'package:damso_app/features/reply/domain/answer_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 문의 탭 답변 대기 · 답변 완료 두 칸(specs/004 US6, Figma F3-1·F3-1b).
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  /// 두 칸 전환의 칸 이름("답변 대기 4"처럼 수가 붙는다). 카드 부제("답변 완료 · …")와 구분한다.
  Finder segment(String name) => find.byWidgetPredicate(
    (w) => w is Text && RegExp('^$name \\d+\$').hasMatch(w.data ?? ''),
  );

  /// 제목과 부제 앞부분이 맞는 목록 항목.
  Finder tile(String title, String subtitlePrefix) => find.byWidgetPredicate(
    (w) =>
        w is ListTile &&
        (w.title as Text).data == title &&
        ((w.subtitle as Text?)?.data ?? '').startsWith(subtitlePrefix),
  );

  Future<void> openInquiries(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await tapTab(tester, '문의');
    await settle(tester);
  }

  testWidgets('처음엔 답변 대기: 답한 뒤 재문의가 온 문의는 "재문의 받음"으로 이 칸에 있다', (tester) async {
    await openInquiries(tester);

    expect(find.text('답변 대기 36'), findsOneWidget); // 서버 totalElements(불러온 20건이 아니라 전체)
    expect(find.text('답변 완료 1'), findsOneWidget);
    expect(tile('친구와 다툰 일 관련 문의', '이도윤 · '), findsOneWidget);
    expect(find.textContaining('답변 완료 · '), findsNothing); // …000b 는 이 칸에 없다
    final followUp = tile('친구 관계 관련 문의', '박서준 · 재문의 받음 · ');
    await tester.ensureVisible(followUp);
    expect(followUp, findsOneWidget);
    expect(find.text('재문의'), findsOneWidget);
  });

  testWidgets('답변 완료로 바꾸면 답한 뒤 재문의가 없는 문의만, 누르면 스레드', (tester) async {
    await openInquiries(tester);
    await tester.tap(segment('답변 완료'));
    await settle(tester);

    final answered = tile('친구 관계 관련 문의', '김하나 · 답변 완료 · ');
    expect(answered, findsOneWidget);
    expect(tile('친구 관계 관련 문의', '박서준 · '), findsNothing);
    expect(tile('친구와 다툰 일 관련 문의', '이도윤 · '), findsNothing);

    await tester.tap(answered);
    await settle(tester);
    expect(find.text(AnswerText.toListButton), findsOneWidget); // 스레드(F4-3)
  });

  testWidgets('답변 대기 문의에 답변을 보내고 목록으로 오면 답변 완료로 옮겨 가 있다', (tester) async {
    await openInquiries(tester);
    final waiting = tile('친구와 다툰 일 관련 문의', '이도윤 · ');
    expect(waiting, findsOneWidget);

    await tester.ensureVisible(waiting);
    await tester.tap(waiting);
    await settle(tester);
    await tapText(tester, AnswerText.writeAnswerButton);
    await tester.enterText(find.byType(TextField), '확인하겠습니다.');
    await tester.pump();
    await tapText(tester, AnswerText.reviewButton);
    await settle(tester);
    await tapText(tester, AnswerText.sendButton);
    await settle(tester);
    await tapText(tester, AnswerText.toListButton);
    await settle(tester);

    expect(tile('친구와 다툰 일 관련 문의', '이도윤 · '), findsNothing);
    await tester.tap(segment('답변 완료'));
    await settle(tester);
    expect(tile('친구와 다툰 일 관련 문의', '이도윤 · 답변 완료 · '), findsOneWidget);
  });
}
