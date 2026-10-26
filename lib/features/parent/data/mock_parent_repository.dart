import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/storage/token_store.dart';
import '../domain/child.dart';
import '../domain/parent_repository.dart';

/// mock 구현. `TokenStore.accessToken`(`mock:<계정>`)으로 데모 계정을 구분한다(quickstart).
/// - parent·signup-parent·refresh: 자녀 2명(김하나 3-2 담임 있음, 김두리 1-1 담임 없음)
/// - newparent: 자녀 0명
/// - expired: 조회 시 세션 만료(onSessionExpired 후 401)
/// - refresh: 첫 조회만 갱신 지연을 흉내 낸 뒤 정상 응답. 토큰은 건드리지 않는다
///   (토큰 갱신은 AuthInterceptor 한 곳에서만, research R8).
class MockParentRepository implements ParentRepository {
  MockParentRepository(this._tokens, this._onSessionExpired);

  final TokenStore _tokens;
  final void Function() _onSessionExpired;

  static const _delay = Duration(milliseconds: 300);

  /// 계정별 자녀 목록(자녀 추가가 반영된다).
  final _children = <String, List<Child>>{};

  /// refresh 데모가 갱신 단계를 이미 거쳤는지.
  bool _refreshSimulated = false;

  static const _kim = Child(
    studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51',
    studentName: '김하나',
    classroom: ClassroomRef(
      classroomId: '5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c81',
      grade: 3,
      classNumber: 2,
    ),
    teacher: TeacherPublicProfile(
      displayName: '이담임',
      introduction: '아이들과 천천히 이야기 나누는 담임입니다.',
    ),
  );

  static const _duri = Child(
    studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e52',
    studentName: '김두리',
    classroom: ClassroomRef(
      classroomId: '5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c82',
      grade: 1,
      classNumber: 1,
    ),
  );

  static const _newChild = Child(
    studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e53',
    studentName: '김새봄',
    classroom: ClassroomRef(
      classroomId: '5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c83',
      grade: 2,
      classNumber: 3,
    ),
    teacher: TeacherPublicProfile(
      displayName: '박담임',
      introduction: '함께 자라는 교실을 만들어요.',
    ),
  );

  String get _account => (_tokens.accessToken ?? '').replaceFirst('mock:', '');

  List<Child> _listFor(String account) => _children.putIfAbsent(
    account,
    () => account == 'newparent' ? [] : [_kim, _duri],
  );

  @override
  Future<List<Child>> listChildren() async {
    await Future<void>.delayed(_delay);
    final account = _account;
    if (account == 'expired') {
      _onSessionExpired();
      throw const AppException(
        message: '인증이 필요합니다.',
        code: ErrorCodes.unauthorized,
        statusCode: 401,
      );
    }
    if (account == 'refresh' && !_refreshSimulated) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _refreshSimulated = true;
    }
    return List.unmodifiable(_listFor(account));
  }

  @override
  Future<Child> linkChild(String inviteCode) async {
    await Future<void>.delayed(_delay);
    if (inviteCode == 'ZZZZZZZZZZ') {
      throw const AppException(
        message: '잠시 후 다시 시도해 주세요.',
        code: ErrorCodes.tooManyAttempts,
        statusCode: 429,
        retryAfter: Duration(seconds: 600),
      );
    }
    final list = _listFor(_account);
    if (inviteCode != 'PARENTCDE2' || list.contains(_newChild)) {
      // 교사 코드·이미 보호자가 있는 학생의 코드도 같은 안내(FR-016)
      throw const AppException(
        message: '코드를 확인해 주세요.',
        code: ErrorCodes.invalidInviteCode,
        statusCode: 400,
      );
    }
    list.add(_newChild);
    return _newChild;
  }
}
