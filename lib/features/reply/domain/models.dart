/// 답변 작성·점검·전송 모델(specs/004 data-model §2). 모두 화면이 열려 있는 동안 메모리에만 둔다.
library;

import '../../inquiry/domain/models.dart';

/// 점검이 짚어 준 문제 표현 한 곳(원본 명세 `Highlight`). 화면에서만 쓰고 로그에 남기지 않는다.
class Highlight {
  const Highlight({
    required this.excerpt,
    required this.reason,
    required this.suggestion,
  });

  /// 답변에서 문제로 지적된 부분("바꾸기" 대상).
  final String excerpt;

  /// 오해 소지·근거 누락 이유.
  final String reason;

  /// 대체 표현 제안("고쳐 쓴 문장").
  final String suggestion;
}

/// 점검 결과(원본 명세 `AnswerReviewResult`). [available] 이 false 면 [highlights] 는 무시한다.
class AnswerReview {
  const AnswerReview({required this.available, required this.highlights});

  final bool available;
  final List<Highlight> highlights;
}

/// 전송 결과(원본 명세 `AnswerSent`).
class AnswerSent {
  const AnswerSent({
    required this.answerId,
    required this.inquiryId,
    required this.sentAt,
  });

  final String answerId;
  final String inquiryId;
  final DateTime sentAt;
}

/// 답변 작성 화면에 넘기는 값. URL 에는 넣지 않고 라우터 `extra` 로만 넘긴다.
class AnswerTarget {
  const AnswerTarget({
    required this.inquiryId,
    required this.studentName,
    required this.title,
    this.requests,
    this.fromThread = false,
  });

  /// 스레드 루트 ID. 점검·전송 경로에 쓴다(research R4).
  final String inquiryId;
  final String studentName;
  final String title;

  /// 정리된 요청사항(재문의에서 왔으면 그 재문의 것). 없으면 요청사항 상자를 숨긴다.
  final String? requests;

  /// 스레드(재문의 상세 경유)에서 왔는지. 전송 뒤 스레드까지 pop 한다(research R14).
  final bool fromThread;
}

/// 스레드 → 재문의 상세로 넘기는 값(research R13).
class FollowUpArgs {
  const FollowUpArgs({
    required this.rootId,
    required this.studentName,
    required this.rootTitle,
    required this.followUp,
  });

  final String rootId;
  final String studentName;
  final String rootTitle;
  final TeacherFollowUp followUp;
}
