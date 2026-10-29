import 'models.dart';

/// 교사 문의(contracts/api-usage.md "inquiry(교사)", specs/002·003).
abstract class TeacherInquiryRepository {
  static const pageSize = 20;

  /// 담당 학급 문의, 긴급 먼저 그다음 최신순(서버가 정렬).
  /// [answerStatus]가 있으면 서버가 답변 여부로 거른다(api-v0.11).
  Future<TeacherInquiryPage> list({
    int page = 0,
    int size = pageSize,
    AnswerStatus? answerStatus,
  });

  Future<TeacherInquiryDetail> detail(String inquiryId);

  /// 원문. 부를 때마다 서버에 열람 기록이 남고, 긴급과 "원문 확인 필요" 문의는 첫 열람 때
  /// "교사 확인"이 된다. 긴급 상세(F3-5)와 원문 열람(F3-6)에서 화면당 한 번만 부른다(research R8·R6).
  Future<String> content(String inquiryId);

  /// 번역본. 정리 상태가 `REFINED`일 때만 부른다. 첫 열람에 "교사 확인"이 된다.
  /// 번역본이 없으면 409 `REFINEMENT_NOT_READY`.
  Future<InquiryRefinement> refinement(String inquiryId);

  /// "원문 확인 필요" 문의를 다시 정리한다(1건당 1회). 받아들인 시점의 정리 상태를 돌려준다.
  /// 다시 정리할 수 없으면 409 `REFINEMENT_RETRY_UNAVAILABLE`.
  Future<RefinementStatus> retryRefinement(String inquiryId);
}
