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
}
