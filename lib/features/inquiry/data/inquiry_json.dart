import '../domain/models.dart';

typedef _Answered = ({bool hasAnswer, DateTime? lastAnsweredAt});

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

  /// 목록 항목의 답변 여부(api-v0.7 `hasAnswer`·`lastAnsweredAt`).
  static _Answered _listAnswered(Map<String, dynamic> j) => (
    hasAnswer: j['hasAnswer'] as bool,
    lastAnsweredAt: _dateOrNull(j['lastAnsweredAt']),
  );

  /// 상세 응답에는 `hasAnswer`가 없어 `answers`(시간순)로 같은 값을 만든다.
  static _Answered _detailAnswered(Map<String, dynamic> j) {
    final answers = (j['answers'] as List?) ?? const [];
    return (
      hasAnswer: answers.isNotEmpty,
      lastAnsweredAt: answers.isEmpty
          ? null
          : DateTime.parse((answers.last as Map)['sentAt'] as String),
    );
  }

  static DateTime? _dateOrNull(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);

  static ParentInquirySummary parentSummary(Map<String, dynamic> j) =>
      _parentSummary(j, _listAnswered(j));

  static ParentInquirySummary _parentSummary(
    Map<String, dynamic> j,
    _Answered answered,
  ) => ParentInquirySummary(
    inquiryId: j['inquiryId'] as String,
    studentId: j['studentId'] as String,
    studentName: j['studentName'] as String,
    urgent: j['urgent'] as bool,
    stage: InquiryStage.fromServer(j['stage'] as String),
    submittedAt: DateTime.parse(j['submittedAt'] as String),
    hasAnswer: answered.hasAnswer,
    lastAnsweredAt: answered.lastAnsweredAt,
  );

  /// 학부모 상세. 응답의 content·followUps 와 답변 본문은 읽지 않는다(학부모 F4 화면의 몫).
  static ParentInquiryDetail parentDetail(Map<String, dynamic> j) =>
      ParentInquiryDetail(
        summary: _parentSummary(j, _detailAnswered(j)),
        timeline: timeline(j['timeline']),
        notices: notices(j['notices']),
        hotlines: hotlines(j['hotlines']),
      );

  /// 목록 항목. 답변 대기 여부·마지막 재문의 시각은 서버 값(api-v0.11 `needsAnswer`·`lastFollowUpAt`).
  static TeacherInquirySummary teacherSummary(Map<String, dynamic> j) => _teacherSummary(
    j,
    _listAnswered(j),
    needsAnswer: j['needsAnswer'] as bool,
    lastFollowUpAt: _dateOrNull(j['lastFollowUpAt']),
  );

  static TeacherInquirySummary _teacherSummary(
    Map<String, dynamic> j,
    _Answered answered, {
    bool? needsAnswer,
    DateTime? lastFollowUpAt,
  }) => TeacherInquirySummary(
    inquiryId: j['inquiryId'] as String,
    studentId: j['studentId'] as String,
    studentName: j['studentName'] as String,
    urgent: j['urgent'] as bool,
    title: j['title'] as String,
    stage: InquiryStage.fromServer(j['stage'] as String),
    refinementStatus: RefinementStatus.fromServer(j['refinementStatus']),
    submittedAt: DateTime.parse(j['submittedAt'] as String),
    hasAnswer: answered.hasAnswer,
    lastAnsweredAt: answered.lastAnsweredAt,
    needsAnswer: needsAnswer,
    lastFollowUpAt: lastFollowUpAt,
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

  /// 교사 상세. `followUps`·`answers`(api-v0.6, specs/004)가 없으면 빈 목록으로 본다.
  /// `threatFlagged`(specs 005)는 읽지 않는다.
  static TeacherInquiryDetail teacherDetail(Map<String, dynamic> j) =>
      TeacherInquiryDetail(
        summary: _teacherSummary(j, _detailAnswered(j)),
        timeline: timeline(j['timeline']),
        retryAvailable: j['retryAvailable'] as bool,
        followUps: [
          for (final f in (j['followUps'] as List? ?? const []).cast<Map<String, dynamic>>())
            teacherFollowUp(f),
        ],
        answers: [
          for (final a in (j['answers'] as List? ?? const []).cast<Map<String, dynamic>>())
            sentAnswer(a),
        ],
      );

  static TeacherFollowUp teacherFollowUp(Map<String, dynamic> j) => TeacherFollowUp(
    inquiryId: j['inquiryId'] as String,
    urgent: j['urgent'] as bool,
    title: j['title'] as String,
    stage: InquiryStage.fromServer(j['stage'] as String),
    submittedAt: DateTime.parse(j['submittedAt'] as String),
  );

  static SentAnswer sentAnswer(Map<String, dynamic> j) => SentAnswer(
    answerId: j['answerId'] as String,
    content: j['content'] as String,
    reviewed: j['reviewed'] as bool,
    sentAt: DateTime.parse(j['sentAt'] as String),
  );

  /// 모르는 정서강도·라벨은 버린다(specs/003 research R8).
  static InquiryRefinement refinement(Map<String, dynamic> j) => InquiryRefinement(
    inquiryId: j['inquiryId'] as String,
    title: j['title'] as String,
    facts: j['facts'] as String,
    requests: j['requests'] as String,
    emotionLevel: EmotionLevel.fromServer(j['emotionLevel']),
    emotionLabels: EmotionLabel.normalize((j['emotionLabels'] as List).cast<Object?>()),
    refinedAt: DateTime.parse(j['refinedAt'] as String),
  );
}
