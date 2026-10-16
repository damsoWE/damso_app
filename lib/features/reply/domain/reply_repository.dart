/// 교사 답변 도메인 계약(F4). 시스템은 점검 결과만 제안하고,
/// 전송은 교사가 직접 수행한다(원칙 5: 자동 발송 없음).
abstract class ReplyRepository {
  Future<void> send({required String inquiryId, required String body});
}
