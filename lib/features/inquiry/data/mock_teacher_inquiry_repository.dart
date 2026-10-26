import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/storage/token_store.dart';
import '../domain/models.dart';
import '../domain/teacher_inquiry_repository.dart';
import 'mock_inquiry_store.dart';

/// mock 구현. 담임 계정(teacher·signup-teacher)은 3학년 2반 문의를 보고,
/// noclass 계정은 담당 학급이 없어 403 이다(F1 quickstart 와 같은 계정).
class MockTeacherInquiryRepository implements TeacherInquiryRepository {
  MockTeacherInquiryRepository(this._tokens, this._store);

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
  Future<TeacherInquiryPage> list({
    int page = 0,
    int size = TeacherInquiryRepository.pageSize,
  }) async {
    await Future<void>.delayed(_delay);
    _checkClassroom();
    return _store.listForTeacher(page: page, size: size);
  }

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) async {
    await Future<void>.delayed(_delay);
    _checkClassroom();
    return _store.detailForTeacher(inquiryId);
  }

  @override
  Future<String> content(String inquiryId) async {
    await Future<void>.delayed(_delay);
    _checkClassroom();
    return _store.contentForTeacher(inquiryId);
  }
}
