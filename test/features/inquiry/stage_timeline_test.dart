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
