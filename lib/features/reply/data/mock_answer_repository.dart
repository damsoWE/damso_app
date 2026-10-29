import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/storage/token_store.dart';
import '../../inquiry/data/mock_inquiry_store.dart';
import '../domain/answer_repository.dart';
import '../domain/models.dart';

/// mock 구현. 교사 문의 mock 과 같은 저장소를 써서 보낸 답변이 스레드에 보인다(research R11).
/// `noclass` 계정은 담당 학급이 없어 403 이다(교사 문의 mock 과 같다).
class MockAnswerRepository implements AnswerRepository {
  MockAnswerRepository(this._tokens, this._store);

  final TokenStore _tokens;
  final MockInquiryStore _store;

  static const _delay = Duration(milliseconds: 300);

  void _checkClassroom() {
    if (_tokens.accessToken == 'mock:noclass') {
      throw const AppException(
        message: '담당 학급이 없습니다.',
        code: ErrorCodes.forbidden,
        statusCode: 403,
      );
    }
  }

  @override
  Future<AnswerReview> review(String inquiryId, String content) async {
    await Future<void>.delayed(_delay);
    _checkClassroom();
    final r = _store.reviewAnswerForTeacher(inquiryId, content);
    return AnswerReview(
      available: r.available,
      highlights: [
        for (final h in r.highlights)
          Highlight(excerpt: h.excerpt, reason: h.reason, suggestion: h.suggestion),
      ],
    );
  }

  @override
  Future<AnswerSent> send(String inquiryId, String content, {required bool reviewed}) async {
    await Future<void>.delayed(_delay);
    _checkClassroom();
    final a = _store.sendAnswerForTeacher(inquiryId, content, reviewed: reviewed);
    return AnswerSent(answerId: a.answerId, inquiryId: inquiryId, sentAt: a.sentAt);
  }
}
