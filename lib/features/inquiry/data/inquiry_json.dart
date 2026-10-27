import '../domain/models.dart';

/// 문의 응답 해석(학부모·교사 실서버 구현 공용). 필드 이름은 원본 명세 0.5.0 그대로.
/// 형식이 다르면 TypeError·FormatException 이 나고 mapDioErrors 가 일반 안내로 바꾼다.
abstract final class InquiryJson {
  static List<StageEvent> timeline(Object? raw) => (raw as List)
      .cast<Map<String, dynamic>>()
      .map(
        (e) => StageEvent(
          stage: InquiryStage.fromServer(e['stage'] as String),
          occurredAt: DateTime.parse(e['occurredAt'] as String),
        ),
      )
      .toList();

  static List<Notice> notices(Object? raw) => [
    for (final v in raw as List) ?Notice.tryParse(v),
  ];

  static List<Hotline> hotlines(Object? raw) =>
      Hotline.normalize((raw as List).cast<Object?>());

  static InquirySubmitted submitted(Map<String, dynamic> j) => InquirySubmitted(
    inquiryId: j['inquiryId'] as String,
    urgent: j['urgent'] as bool,
    stage: InquiryStage.fromServer(j['stage'] as String),
    submittedAt: DateTime.parse(j['submittedAt'] as String),
    notices: notices(j['notices']),
    hotlines: hotlines(j['hotlines']),
  );

  static ParentInquirySummary parentSummary(Map<String, dynamic> j) =>
      ParentInquirySummary(
        inquiryId: j['inquiryId'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String,
        urgent: j['urgent'] as bool,
        stage: InquiryStage.fromServer(j['stage'] as String),
        submittedAt: DateTime.parse(j['submittedAt'] as String),
      );

  /// 응답의 content·followUps·answers 는 읽지 않는다(F4 화면의 몫).
  static ParentInquiryDetail parentDetail(Map<String, dynamic> j) =>
      ParentInquiryDetail(
        summary: parentSummary(j),
        timeline: timeline(j['timeline']),
        notices: notices(j['notices']),
        hotlines: hotlines(j['hotlines']),
      );

  static TeacherInquirySummary teacherSummary(Map<String, dynamic> j) =>
      TeacherInquirySummary(
        inquiryId: j['inquiryId'] as String,
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String,
        urgent: j['urgent'] as bool,
        title: j['title'] as String,
        stage: InquiryStage.fromServer(j['stage'] as String),
        refinementStatus: RefinementStatus.fromServer(j['refinementStatus']),
        submittedAt: DateTime.parse(j['submittedAt'] as String),
      );

  static TeacherInquiryPage teacherPage(Map<String, dynamic> j) =>
      TeacherInquiryPage(
        items: (j['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(teacherSummary)
            .toList(),
        page: j['page'] as int,
        size: j['size'] as int,
        totalElements: j['totalElements'] as int,
      );

  static TeacherInquiryDetail teacherDetail(Map<String, dynamic> j) =>
      TeacherInquiryDetail(
        summary: teacherSummary(j),
        timeline: timeline(j['timeline']),
      );
}
