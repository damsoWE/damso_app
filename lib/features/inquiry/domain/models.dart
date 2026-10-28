/// 문의 화면 모델(specs/002 data-model §1~3). 서버 값 해석은 각 enum 의 `fromServer`가 맡고,
/// 모르는 단계 값은 [FormatException] 을 던져 data 계층이 일반 안내로 바꾼다.
library;

/// 처리 단계. 서버 `REFINING`은 이름과 달리 "정제 완료" 시점이다.
enum InquiryStage {
  received('RECEIVED'),
  delivered('DELIVERED'),
  refined('REFINING'),
  teacherConfirmed('TEACHER_CONFIRMED'),
  answered('ANSWERED');

  const InquiryStage(this.serverValue);

  final String serverValue;

  static InquiryStage fromServer(String value) => values.firstWhere(
    (s) => s.serverValue == value,
    orElse: () => throw FormatException('알 수 없는 단계'),
  );

  /// 타임라인에 그릴 단계 순서.
  static List<InquiryStage> flowOf({required bool urgent}) => urgent
      ? const [received, delivered, teacherConfirmed, answered]
      : const [received, refined, teacherConfirmed, answered];
}

class StageEvent {
  const StageEvent({required this.stage, required this.occurredAt});

  final InquiryStage stage;
  final DateTime occurredAt;
}

/// 학부모 화면의 시스템 안내 코드. 문구는 notice_text.dart 에만 있다.
enum Notice {
  received('RECEIVED'),
  urgentDelivered('URGENT_DELIVERED'),
  deferred('DEFERRED_TO_AVAILABLE_HOURS');

  const Notice(this.serverValue);

  final String serverValue;

  /// 모르는 코드는 null(버린다).
  static Notice? tryParse(Object? value) {
    for (final n in values) {
      if (n.serverValue == value) return n;
    }
    return null;
  }
}

/// 긴급 문의의 외부 상담·신고 번호.
enum Hotline {
  childAbuse('CHILD_ABUSE_112', '112'),
  suicidePrevention('SUICIDE_PREVENTION_109', '109');

  const Hotline(this.serverValue, this.phoneNumber);

  final String serverValue;
  final String phoneNumber;

  static Hotline? tryParse(Object? value) {
    for (final h in values) {
      if (h.serverValue == value) return h;
    }
    return null;
  }

  /// 서버 번호 목록 정리(research R5): 모르는 코드는 버리고, 버린 뒤 비었는데
  /// 서버가 하나 이상 줬다면 기본 안내(112·109)로 바꾼다.
  static List<Hotline> normalize(List<Object?> raw) {
    final known = <Hotline>[];
    for (final value in raw) {
      final h = tryParse(value);
      if (h != null && !known.contains(h)) known.add(h);
    }
    if (known.isEmpty && raw.isNotEmpty) return const [childAbuse, suicidePrevention];
    return known;
  }
}

/// 보낸 뒤 보여 줄 안내 화면(data-model §1 SubmitOutcome).
sealed class SubmitOutcome {
  const SubmitOutcome();

  /// 서버 결과로 안내 화면을 고른다. [hotlines]는 정리된 목록이어야 한다.
  factory SubmitOutcome.from({
    required bool urgent,
    required List<Notice> notices,
    required List<Hotline> hotlines,
  }) {
    if (urgent) return UrgentNotice(hotlines);
    if (notices.contains(Notice.deferred)) return const DeferredNotice();
    return const ReceivedNotice();
  }
}

final class ReceivedNotice extends SubmitOutcome {
  const ReceivedNotice();
}

final class DeferredNotice extends SubmitOutcome {
  const DeferredNotice();
}

final class UrgentNotice extends SubmitOutcome {
  const UrgentNotice(this.hotlines);

  final List<Hotline> hotlines;
}

class InquirySubmitted {
  const InquirySubmitted({
    required this.inquiryId,
    required this.urgent,
    required this.stage,
    required this.submittedAt,
    required this.notices,
    required this.hotlines,
  });

  final String inquiryId;
  final bool urgent;
  final InquiryStage stage;
  final DateTime submittedAt;
  final List<Notice> notices;
  final List<Hotline> hotlines;

  SubmitOutcome get outcome =>
      SubmitOutcome.from(urgent: urgent, notices: notices, hotlines: hotlines);
}

/// 학부모 문의 목록 카드. 서버 제목은 없다(spec FR-016).
class ParentInquirySummary {
  const ParentInquirySummary({
    required this.inquiryId,
    required this.studentId,
    required this.studentName,
    required this.urgent,
    required this.stage,
    required this.submittedAt,
    required this.hasAnswer,
    required this.lastAnsweredAt,
  });

  final String inquiryId;
  final String studentId;
  final String studentName;
  final bool urgent;
  final InquiryStage stage;
  final DateTime submittedAt;

  /// 스레드(최초 문의 + 재문의)에 답변이 1건 이상 있는지(api-v0.7).
  /// "답변한 문의는 스레드로"는 [stage]가 아니라 이 값으로 판단한다.
  final bool hasAnswer;

  /// 스레드의 마지막 답변 시각. 답변이 없으면 null.
  final DateTime? lastAnsweredAt;

  /// 화면에 보일 단계. 서버는 [InquiryStage.answered]를 만들지 않으므로(api-v0.7)
  /// 답변이 있으면 "답변 완료"로 보인다.
  InquiryStage get displayStage => hasAnswer ? InquiryStage.answered : stage;
}

/// 카드 펼침·긴급 안내 다시 보기용. 원문·재문의·답변은 F4 화면의 몫이라 담지 않는다.
class ParentInquiryDetail {
  const ParentInquiryDetail({
    required this.summary,
    required this.timeline,
    required this.notices,
    required this.hotlines,
  });

  final ParentInquirySummary summary;
  final List<StageEvent> timeline;
  final List<Notice> notices;
  final List<Hotline> hotlines;

  SubmitOutcome get outcome => SubmitOutcome.from(
    urgent: summary.urgent,
    notices: notices,
    hotlines: hotlines,
  );
}

/// 일반 문의의 정리 상태. 긴급 문의는 null.
enum RefinementStatus {
  pending('PENDING'),
  refined('REFINED'),
  needsOriginal('NEEDS_ORIGINAL');

  const RefinementStatus(this.serverValue);

  final String serverValue;

  static RefinementStatus? fromServer(Object? value) {
    if (value == null) return null;
    return values.firstWhere(
      (s) => s.serverValue == value,
      orElse: () => throw FormatException('알 수 없는 정리 상태'),
    );
  }
}

/// 교사 문의 목록 항목. 학부모 정보는 없다(spec FR-023).
class TeacherInquirySummary {
  const TeacherInquirySummary({
    required this.inquiryId,
    required this.studentId,
    required this.studentName,
    required this.urgent,
    required this.title,
    required this.stage,
    required this.refinementStatus,
    required this.submittedAt,
    required this.hasAnswer,
    required this.lastAnsweredAt,
  });

  final String inquiryId;
  final String studentId;
  final String studentName;
  final bool urgent;

  /// 서버가 정한 제목("긴급 문의"·"정리 중"·"원문 확인 필요"·정리된 제목).
  final String title;
  final InquiryStage stage;
  final RefinementStatus? refinementStatus;
  final DateTime submittedAt;

  /// 스레드에 답변이 1건 이상 있는지(api-v0.7). 답변 여부는 [stage]가 아니라 이 값으로 판단한다.
  final bool hasAnswer;

  /// 스레드의 마지막 답변 시각(이전 담임의 답변 포함). 답변이 없으면 null.
  final DateTime? lastAnsweredAt;

  /// 화면에 보일 단계. 답변이 있으면 "답변 완료"(api-v0.7, [ParentInquirySummary.displayStage]와 같음).
  InquiryStage get displayStage => hasAnswer ? InquiryStage.answered : stage;

  /// 교사가 아직 원문을 열지 않은 긴급 문의(교사 홈 긴급 카드).
  bool get isUnconfirmedUrgent => urgent && stage == InquiryStage.delivered;
}

class TeacherInquiryPage {
  const TeacherInquiryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
  });

  final List<TeacherInquirySummary> items;
  final int page;
  final int size;
  final int totalElements;

  bool get hasMore => (page + 1) * size < totalElements;
}

/// 교사 문의 상세(본문·번역본 없음). 원문은 [TeacherInquiryRepository.content],
/// 번역본은 [TeacherInquiryRepository.refinement] 로 따로 연다.
class TeacherInquiryDetail {
  const TeacherInquiryDetail({
    required this.summary,
    required this.timeline,
    required this.retryAvailable,
  });

  final TeacherInquirySummary summary;
  final List<StageEvent> timeline;

  /// "원문 확인 필요"이고 교사 재시도(1건당 1회)를 아직 쓰지 않았으면 true.
  final bool retryAvailable;
}

/// 정서강도 3단계(specs/003 data-model). 모르는 값은 null 로 버린다(research R8).
enum EmotionLevel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const EmotionLevel(this.serverValue);

  final String serverValue;

  static EmotionLevel? fromServer(Object? value) {
    for (final l in values) {
      if (l.serverValue == value) return l;
    }
    return null;
  }
}

/// 감정 라벨 고정 목록. 모르는 값은 null 로 버린다(research R8).
enum EmotionLabel {
  anxiety('ANXIETY'),
  dissatisfaction('DISSATISFACTION'),
  anger('ANGER'),
  worry('WORRY'),
  frustration('FRUSTRATION'),
  sadness('SADNESS');

  const EmotionLabel(this.serverValue);

  final String serverValue;

  static EmotionLabel? fromServer(Object? value) {
    for (final l in values) {
      if (l.serverValue == value) return l;
    }
    return null;
  }

  /// 모르는 값과 중복을 빼고 앞에서 2개까지.
  static List<EmotionLabel> normalize(List<Object?> raw) =>
      raw.map(fromServer).whereType<EmotionLabel>().toSet().take(2).toList();
}

/// 번역본(일반 문의 정리 결과). 서버가 이름·학급을 원래 값으로 되돌려 준다.
/// 화면이 열려 있는 동안 메모리에만 둔다(원칙 III·VI).
class InquiryRefinement {
  const InquiryRefinement({
    required this.inquiryId,
    required this.title,
    required this.facts,
    required this.requests,
    required this.emotionLevel,
    required this.emotionLabels,
    required this.refinedAt,
  });

  final String inquiryId;
  final String title;

  /// 사실관계.
  final String facts;

  /// 요청사항. 없으면 빈 문자열.
  final String requests;

  /// 앱이 모르는 값이면 null(정서강도 줄을 숨긴다).
  final EmotionLevel? emotionLevel;

  /// 0~2개.
  final List<EmotionLabel> emotionLabels;
  final DateTime refinedAt;
}
