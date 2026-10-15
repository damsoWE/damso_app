/// 문의 한 건의 화면용 모델. 식별자는 UUID 문자열(원칙 7).
/// 상태 전이 mock 용으로 refining(정제 중) → refined(완료) 외에
/// 실패 시 "원문 확인 필요"(원칙 4, fail-closed)와 긴급 표시를 포함한다.
enum InquiryStatus { refining, refined, needsOriginalCheck }

class Inquiry {
  const Inquiry({
    required this.id,
    required this.status,
    required this.summary,
    this.urgent = false,
  });

  final String id;
  final InquiryStatus status;
  final String summary;
  final bool urgent;
}

abstract interface class InquiryRepository {
  Future<List<Inquiry>> list();
}
