import '../domain/history_repository.dart';

/// mock 구현(서버 불필요). 이력 항목 ID(UUID) 몇 개를 돌려준다.
class MockHistoryRepository implements HistoryRepository {
  @override
  Future<List<String>> listEntryIds(String inquiryId) async => const [
    '10000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002',
  ];
}
