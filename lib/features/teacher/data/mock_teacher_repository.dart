import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/storage/token_store.dart';
import '../domain/models.dart';
import '../domain/teacher_repository.dart';

/// mock 구현. `noclass` 데모 계정은 담당 학급 조회가 403 이다(research R8).
class MockTeacherRepository implements TeacherRepository {
  MockTeacherRepository(this._tokens);

  final TokenStore _tokens;

  static const _delay = Duration(milliseconds: 300);

  TeacherProfile _profile = const TeacherProfile(
    displayName: '이담임',
    introduction: '아이들과 천천히 이야기 나누는 담임입니다.',
  );

  @override
  Future<TeacherProfile> getProfile() async {
    await Future<void>.delayed(_delay);
    return _profile;
  }

  @override
  Future<TeacherProfile> updateProfile(TeacherProfile profile) async {
    await Future<void>.delayed(_delay);
    _profile = profile;
    return _profile;
  }

  @override
  Future<MyClassroom> getMyClassroom() async {
    await Future<void>.delayed(_delay);
    if (_tokens.accessToken == 'mock:noclass') {
      throw const AppException(
        message: '권한이 없습니다.',
        code: ErrorCodes.forbidden,
        statusCode: 403,
      );
    }
    return const MyClassroom(
      classroomId: '5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c81',
      grade: 3,
      classNumber: 2,
      students: [
        StudentLink(
          studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51',
          name: '김하나',
          guardianLinked: true,
        ),
        StudentLink(
          studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e61',
          name: '박서준',
          guardianLinked: false,
        ),
        StudentLink(
          studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e62',
          name: '이도윤',
          guardianLinked: false,
        ),
      ],
    );
  }
}
