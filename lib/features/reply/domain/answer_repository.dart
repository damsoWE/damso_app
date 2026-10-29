import 'models.dart';

/// 교사 답변 점검·전송(specs/004 contracts/api-usage.md). [inquiryId]는 언제나 스레드 루트다.
abstract class AnswerRepository {
  /// 전송 전 점검. 점검 실패는 오류가 아니라 `available == false`다.
  Future<AnswerReview> review(String inquiryId, String content);

  /// 답변 전송. 이미 종료된 문의면 409 `THREAD_CLOSED`.
  /// [lastSeenFollowUpId]: 교사가 화면에서 본 마지막 재문의 ID(없으면 null, api-v0.11).
  /// 스레드의 최신 재문의와 다르면 409 `NEW_FOLLOW_UP`이고 답변은 저장되지 않는다.
  /// 멱등키가 없으므로 호출하는 쪽에서 자동으로 다시 보내지 않는다(research R8).
  Future<AnswerSent> send(
    String inquiryId,
    String content, {
    required bool reviewed,
    required String? lastSeenFollowUpId,
  });
}
