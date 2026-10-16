import '../domain/reply_repository.dart';

/// mock 구현(서버 불필요). 전송은 성공한 것으로 처리한다. 본문은 저장·출력하지 않는다.
class MockReplyRepository implements ReplyRepository {
  @override
  Future<void> send({required String inquiryId, required String body}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
