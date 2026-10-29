import 'package:damso_app/features/reply/domain/answer_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 번역본·원문을 연 뒤 뒤에서 도는 목록 새로 고침(mock 300ms)까지 끝낸다.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> tapSettle(WidgetTester tester, String text) async {
  await tapText(tester, text);
  await settle(tester);
}

/// 교사 답변 화면 흐름(specs/004 quickstart, mock 데모 research R11).
void main() {
  Future<void> teacherInquiries(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await tapTab(tester, '문의');
  }

  /// 교사 문의 탭에서 제목·학생이 맞는 항목을 연다.
  Future<void> openInquiry(WidgetTester tester, String title, String student) async {
    final tiles = find.byType(ListTile);
    final list = tester.widgetList<ListTile>(tiles).toList();
    final index = list.indexWhere(
      (t) =>
          (t.title as Text).data == title &&
          ((t.subtitle as Text?)?.data ?? '').startsWith(student),
    );
    expect(index, isNot(-1), reason: '$title · $student 항목이 목록에 없다');
    await tester.ensureVisible(tiles.at(index));
    await tester.tap(tiles.at(index));
    await settle(tester);
  }

  /// 화면에 이메일 형태 글자가 없다(spec FR-024).
  void expectNoEmail(WidgetTester tester) {
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
    expect(texts.where((t) => t.contains('@')), isEmpty);
  }

  Future<void> typeAnswer(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('US1: F3-2 → 답변 작성 → 점검 → 직접 전송 → 스레드(quickstart 1·2·4·10·11)', (
    tester,
  ) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await tapSettle(tester, AnswerText.writeAnswerButton);

    // F4-2a
    expect(find.text(AnswerText.recipient('이도윤')), findsOneWidget);
    expect(find.text('친구와 다툰 일 관련 문의'), findsOneWidget);
    expect(find.text(AnswerText.requestsLabel), findsOneWidget);
    expect(find.text(AnswerText.notSentHint), findsOneWidget);
    expect(isEnabled(tester, AnswerText.reviewButton), isFalse);
    expect(find.text(AnswerText.sendButton), findsNothing);

    // 공백만 → 점검 불가
    await typeAnswer(tester, '   ');
    expect(isEnabled(tester, AnswerText.reviewButton), isFalse);

    // F4-2a-2: "답변 점검"만, 전송 버튼 없음
    await typeAnswer(tester, '확인하겠습니다.');
    expect(isEnabled(tester, AnswerText.reviewButton), isTrue);
    expect(find.text(AnswerText.sendButton), findsNothing);
    expectNoEmail(tester);

    // 점검 → 제안 없음(F4-2e)
    await tapSettle(tester, AnswerText.reviewButton);
    expect(find.text(AnswerText.noSuggestionBadge), findsOneWidget);
    expect(find.text(AnswerText.noSuggestion), findsOneWidget);

    // 직접 전송 → 스레드
    await tapSettle(tester, AnswerText.sendButton);
    expect(find.text('확인하겠습니다.'), findsOneWidget);
    expect(find.text(AnswerText.sentNotice), findsOneWidget);
    expect(find.text(AnswerText.toListButton), findsOneWidget);
    expect(find.text('답변 완료로 닫기'), findsNothing);
    expectNoEmail(tester);
  });

  testWidgets('US1: 본문이 있으면 뒤로 가기 전에 확인한다(FR-003, quickstart 24)', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await tapSettle(tester, AnswerText.writeAnswerButton);
    await typeAnswer(tester, '작성 중인 답변');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AnswerText.discardConfirm), findsOneWidget);
    await tapText(tester, AnswerText.discardCancel);
    expect(find.text('작성 중인 답변'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapSettle(tester, AnswerText.discardLeave);
    expect(find.text(AnswerText.writeAnswerButton), findsOneWidget); // F3-2 로 돌아옴
    expect(find.text('작성 중인 답변'), findsNothing);
  });

  testWidgets('US1: 전송 실패(F4-2h) — 본문 유지, 다시 보내기·답변 수정(quickstart 13)', (
    tester,
  ) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await tapSettle(tester, AnswerText.writeAnswerButton);
    await typeAnswer(tester, '전송실패 데모');
    await tapSettle(tester, AnswerText.reviewButton);
    await tapSettle(tester, AnswerText.sendButton);

    expect(find.text(AnswerText.sendFailedHeading), findsOneWidget);
    expect(find.text('전송실패 데모'), findsOneWidget);
    expect(find.text(AnswerText.maybeSentHint), findsOneWidget);
    expect(find.text(AnswerText.resendButton), findsOneWidget);
    expect(find.text(AnswerText.editButton), findsOneWidget);
  });

  testWidgets('US2: 제안 바꾸기·되돌리기, 직접 고치면 결과가 사라진다(quickstart 5~9)', (
    tester,
  ) async {
    const figmaText = '어제 일은 확인해 보니 큰 문제는 아니었습니다. 확인되는 대로 연락드리겠습니다.';
    const rewritten = '걱정 많으셨겠어요. 어제 상황을 아이들과 확인하고 있습니다. 확인되는 대로 연락드리겠습니다.';

    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await tapSettle(tester, AnswerText.writeAnswerButton);
    await typeAnswer(tester, figmaText);
    await tapSettle(tester, AnswerText.reviewButton);

    // F4-2c
    expect(find.text(AnswerText.suggestionCount(2)), findsOneWidget);
    expect(find.text(AnswerText.suggestionTitle(1, applied: false)), findsOneWidget);
    expect(find.text(AnswerText.suggestionTitle(2, applied: false)), findsOneWidget);
    expect(find.text('걱정을 가볍게 여기는 말로 읽힐 수 있어요.'), findsOneWidget);
    expect(find.text('“이번 주 안 회신” 요청에 대한 설명이 빠져 있어요.'), findsOneWidget);
    expect(find.text(AnswerText.rewrittenLabel), findsNWidgets(2));
    expect(find.text(AnswerText.resultHint), findsOneWidget);
    expect(find.text(AnswerText.editButton), findsOneWidget);
    expect(find.text(AnswerText.sendButton), findsOneWidget);
    expect(find.textContaining('오해할 수 있는 표현'), findsNothing); // 분류 제목을 만들지 않는다
    expect(find.text(figmaText), findsOneWidget);

    // F4-2c-1: 제안 1 바꾸기
    await tester.tap(find.text(AnswerText.applyButton).first);
    await tester.pump();
    expect(find.text(AnswerText.suggestionTitle(1, applied: true)), findsOneWidget);
    expect(find.text(AnswerText.appliedLabel), findsOneWidget);
    expect(find.text(AnswerText.undoButton), findsOneWidget);
    expect(find.text(AnswerText.appliedCount(1)), findsOneWidget);
    expect(find.text(AnswerText.appliedHint), findsOneWidget);
    expect(find.text(rewritten), findsOneWidget);

    // 되돌리기
    await tester.tap(find.text(AnswerText.undoButton));
    await tester.pump();
    expect(find.text(figmaText), findsOneWidget);
    expect(find.text(AnswerText.suggestionCount(2)), findsOneWidget);

    // F4-2d: 답변 수정 → 직접 고침
    await tapSettle(tester, AnswerText.editButton);
    await typeAnswer(tester, '$figmaText 감사합니다.');
    expect(find.text(AnswerText.editedLabel), findsOneWidget);
    expect(find.text(AnswerText.editedNotice), findsOneWidget);
    expect(find.text(AnswerText.recheckButton), findsOneWidget);
    expect(find.text(AnswerText.sendEditedButton), findsOneWidget);
    expect(find.text(AnswerText.suggestionTitle(1, applied: false)), findsNothing);

    // 다른 본문으로 다시 점검 → F4-2e
    await typeAnswer(tester, '확인하겠습니다.');
    await tapSettle(tester, AnswerText.recheckButton);
    expect(find.text(AnswerText.noSuggestionBadge), findsOneWidget);
    expect(find.text(AnswerText.noSuggestion), findsOneWidget);
    expectNoEmail(tester);
  });

  testWidgets('US4: 답변한 문의 → 스레드, 최초 문의 카드 "원문 보기" → F3-6 → 뒤로(quickstart 16·17)', (
    tester,
  ) async {
    await teacherInquiries(tester);
    await settle(tester);
    await tester.tap(find.textContaining(RegExp(r'^답변 완료 \d+$')));
    await settle(tester);
    await openInquiry(tester, '친구 관계 관련 문의', '김하나');

    expect(find.text(AnswerText.parentCardTitle('김하나', followUp: false)), findsOneWidget);
    expect(find.text(AnswerText.answerCardTitle('이담임')), findsOneWidget);
    expect(find.text(AnswerText.viewOriginalButton), findsOneWidget);
    expect(find.text(AnswerText.toListButton), findsOneWidget);
    expect(find.text('답변 완료로 닫기'), findsNothing);
    expect(find.text('문의 상세'), findsNothing); // F3 상세가 아니다

    await tapSettle(tester, AnswerText.viewOriginalButton);
    expect(find.text('작성한 원문'), findsOneWidget);
    expect(find.text(AnswerText.writeAnswerButton), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(find.text(AnswerText.parentCardTitle('김하나', followUp: false)), findsOneWidget);
    expectNoEmail(tester);
  });

  testWidgets('US4: 재문의 카드 → 재문의 상세 → 원문 보기·답변 작성 → 스레드 한 겹(quickstart 18~19b)', (
    tester,
  ) async {
    const rootTitle = '친구 관계 관련 문의';
    const followUpRequests = '금요일 안내 전에 중간 상황도 알려 주실 수 있는지 문의';

    await teacherInquiries(tester);
    await settle(tester);
    // 재문의가 와도 답변 완료 칸에 있다(FR-031).
    await tester.tap(find.textContaining(RegExp(r'^답변 완료 \d+$')));
    await settle(tester);
    await openInquiry(tester, rootTitle, '박서준');

    final followUpCard = find.text(AnswerText.parentCardTitle('박서준', followUp: true));
    expect(followUpCard, findsOneWidget);
    expect(find.textContaining('재문의 받음 · 눌러서 확인'), findsOneWidget);
    expect(find.text(followUpRequests), findsOneWidget);

    // 재문의 상세(F4-3b)
    await tester.ensureVisible(followUpCard);
    await tester.tap(followUpCard);
    await settle(tester);
    expect(find.text(AnswerText.followUpTitle(rootTitle)), findsOneWidget);
    expect(find.textContaining('박서준 학부모 · '), findsOneWidget);
    expect(find.text(followUpRequests), findsOneWidget);
    expect(find.text(AnswerText.viewOriginalButton), findsOneWidget);
    expect(find.text(AnswerText.writeAnswerButton), findsOneWidget);

    // 원문 보기(F3-6 재문의) → 뒤로
    await tapSettle(tester, AnswerText.viewOriginalButton);
    expect(find.text(AnswerText.followUpTitle(rootTitle)), findsOneWidget);
    expect(find.textContaining('그 전에 지금까지 확인된 내용'), findsOneWidget);
    expect(find.text(AnswerText.writeAnswerButton), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // 답변 작성 → 요청사항은 재문의 것 → 점검 → 직접 전송
    await tapSettle(tester, AnswerText.writeAnswerButton);
    expect(find.text(followUpRequests), findsOneWidget);
    await typeAnswer(tester, '오늘까지 확인된 내용 먼저 안내드리겠습니다.');
    await tapSettle(tester, AnswerText.reviewButton);
    await tapSettle(tester, AnswerText.sendButton);

    // 스레드로 돌아옴: 새 답변이 끝에, "눌러서 확인"은 사라짐
    expect(find.text('오늘까지 확인된 내용 먼저 안내드리겠습니다.'), findsOneWidget);
    expect(find.textContaining('눌러서 확인'), findsNothing);
    expect(find.text(AnswerText.toListButton), findsOneWidget);

    // 스레드는 한 겹 — 뒤로 가면 목록
    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining(RegExp(r'^답변 대기 \d+$')), findsOneWidget);
    expectNoEmail(tester);
  });

  testWidgets('US3: 점검 실패(F4-2f) — 본문 그대로, 직접 확인 후 전송 → 스레드(quickstart 12)', (
    tester,
  ) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await tapSettle(tester, AnswerText.writeAnswerButton);
    await typeAnswer(tester, '점검실패 데모 답변');
    await tapSettle(tester, AnswerText.reviewButton);

    expect(find.text(AnswerText.reviewFailed), findsOneWidget);
    expect(find.text(AnswerText.reviewFailedGuide), findsOneWidget);
    expect(find.text(AnswerText.recheckButton), findsOneWidget);
    expect(find.text(AnswerText.sendAfterCheckButton), findsOneWidget);
    expect(find.text('점검실패 데모 답변'), findsOneWidget);
    expect(find.text(AnswerText.applyButton), findsNothing);

    await tapSettle(tester, AnswerText.sendAfterCheckButton);
    expect(find.text('점검실패 데모 답변'), findsOneWidget);
    expect(find.text(AnswerText.sentNotice), findsOneWidget);
    expect(find.text(AnswerText.toListButton), findsOneWidget);
  });
}
