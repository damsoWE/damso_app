import '../domain/inquiry_repository.dart';

/// mock 구현(서버 불필요). 정상 응답 외에 정제 진행 중 → 완료 전이,
/// "원문 확인 필요", 긴급 문의를 담는다. 401/403 은 상세 API 가 확정되면 추가한다.
class MockInquiryRepository implements InquiryRepository {
  int _calls = 0;

  @override
  Future<List<Inquiry>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _calls++;
    return [
      const Inquiry(
        id: '00000000-0000-4000-8000-000000000001',
        status: InquiryStatus.refined,
        summary: '정제 완료된 문의 예시',
      ),
      // 첫 조회에서는 정제 중, 이후 조회부터 완료로 바뀐다.
      Inquiry(
        id: '00000000-0000-4000-8000-000000000002',
        status: _calls == 1 ? InquiryStatus.refining : InquiryStatus.refined,
        summary: '정제 진행 중이던 문의 예시',
      ),
      const Inquiry(
        id: '00000000-0000-4000-8000-000000000003',
        status: InquiryStatus.needsOriginalCheck,
        summary: '원문 확인 필요',
      ),
      const Inquiry(
        id: '00000000-0000-4000-8000-000000000004',
        status: InquiryStatus.refined,
        summary: '긴급 문의 예시',
        urgent: true,
      ),
    ];
  }
}
