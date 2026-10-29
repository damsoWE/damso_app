import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/presentation/stage_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버는 "답변 완료" 단계를 기록하지 않는다(api-v0.7). 그 칸은 답변 시각으로 채운다.
void main() {
  final events = [
    StageEvent(
      stage: InquiryStage.received,
      occurredAt: DateTime(2026, 10, 28, 9),
    ),
    StageEvent(
      stage: InquiryStage.refined,
      occurredAt: DateTime(2026, 10, 28, 9, 1),
    ),
    StageEvent(
      stage: InquiryStage.teacherConfirmed,
      occurredAt: DateTime(2026, 10, 28, 10),
    ),
  ];

  Future<void> pump(WidgetTester tester, {DateTime? answeredAt}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StageTimeline(
              urgent: false,
              events: events,
              answeredAt: answeredAt,
            ),
          ),
        ),
      );

  testWidgets('답변이 없으면 "답변 완료"는 빈 점', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.circle), findsNWidgets(3));
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
  });

  testWidgets('답변 시각이 있으면 "답변 완료"를 채운다', (tester) async {
    await pump(tester, answeredAt: DateTime(2026, 10, 28, 11));

    expect(find.byIcon(Icons.circle), findsNWidgets(4));
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
  });

  testWidgets('처리 단계 이름과 시각만 그린다 — 열람·재시도·점검 같은 감사 항목은 없다(F5 FR-008)', (
    tester,
  ) async {
    await pump(tester, answeredAt: DateTime(2026, 10, 28, 11));

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    for (final word in ['열람', '재시도', '점검', '다시 정리', '종료']) {
      expect(texts.where((t) => t.contains(word)), isEmpty, reason: word);
    }
    expect(find.byIcon(Icons.circle), findsNWidgets(4)); // 단계 4칸뿐
  });

  test('원문 열람·점검 요청을 거친 문의도 학부모·교사 타임라인이 같은 처리 단계 목록이다(F5 US2-1·2)', () {
    final store = MockInquiryStore();
    const id = 'a1000000-0000-4000-8000-000000000005'; // 정리 완료 · 교사 확인(학부모 parent)
    final before = store.detailForTeacher(id).timeline.length;

    store.contentForTeacher(id);
    store.contentForTeacher(id);
    store.reviewAnswerForTeacher(id, '확인하겠습니다.');
    store.reviewAnswerForTeacher(id, '점검실패');

    final teacher = store.detailForTeacher(id).timeline;
    final parent = store.detailForParent('parent', id).timeline;
    expect(teacher, hasLength(before)); // 열람·점검이 단계로 더해지지 않는다
    expect(
      parent.map((e) => (e.stage, e.occurredAt)),
      teacher.map((e) => (e.stage, e.occurredAt)),
    );
    expect(
      teacher.map((e) => e.stage),
      [InquiryStage.received, InquiryStage.refined, InquiryStage.teacherConfirmed],
    );
  });

  test('displayStage: 답변이 있으면 단계와 관계없이 답변 완료', () {
    ParentInquirySummary summary({required bool hasAnswer}) =>
        ParentInquirySummary(
          inquiryId: 'i',
          studentId: 's',
          studentName: '김하나',
          urgent: false,
          stage: InquiryStage.teacherConfirmed,
          submittedAt: DateTime(2026, 10, 28),
          hasAnswer: hasAnswer,
          lastAnsweredAt: hasAnswer ? DateTime(2026, 10, 28, 11) : null,
        );

    expect(
      summary(hasAnswer: false).displayStage,
      InquiryStage.teacherConfirmed,
    );
    expect(summary(hasAnswer: true).displayStage, InquiryStage.answered);
  });
}
