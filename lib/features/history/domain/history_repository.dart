/// 이력 조회 도메인 계약(F5). 문의 원문은 append-only 라서
/// 클라이언트에는 수정·삭제 경로를 만들지 않는다(원칙 3).
abstract class HistoryRepository {
  Future<List<String>> listEntryIds(String inquiryId);
}
