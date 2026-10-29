import 'models.dart';

/// 학부모 문의(contracts/api-usage.md "inquiry(학부모)").
abstract class ParentInquiryRepository {
  /// 같은 [idempotencyKey]로 다시 보내면 처음 결과를 그대로 받는다(research R3).
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  });

  /// 본인이 보낸 문의, 최신순.
  Future<List<ParentInquirySummary>> list();

  Future<ParentInquiryDetail> detail(String inquiryId);

  /// 스레드에 이어서 묻는다. [inquiryId]는 스레드 루트(처음 문의) ID.
  /// 같은 [idempotencyKey]로 다시 보내면 처음 결과를 그대로 받는다(research R4).
  Future<FollowUpSubmitted> submitFollowUp({
    required String inquiryId,
    required String content,
    required String idempotencyKey,
  });
}
