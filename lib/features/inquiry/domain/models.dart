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
  });

  final String inquiryId;
  final String studentId;
  final String studentName;
  final bool urgent;
  final InquiryStage stage;
  final DateTime submittedAt;
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

/// 교사 문의 상세(본문 없음). 원문은 [TeacherInquiryRepository.content] 로 따로 연다.
class TeacherInquiryDetail {
  const TeacherInquiryDetail({required this.summary, required this.timeline});

  final TeacherInquirySummary summary;
  final List<StageEvent> timeline;
}
