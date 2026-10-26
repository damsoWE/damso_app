import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/session/role.dart';
import '../../../core/storage/token_store.dart';
import '../domain/me.dart';
import '../domain/me_repository.dart';

/// mock 구현. `TokenStore.accessToken`(`mock:<계정>`)으로 데모 계정의 내 정보를 돌려준다.
/// 탈퇴 비밀번호는 `damso1234` 만 성공, 슈퍼 관리자는 FORBIDDEN.
class MockMeRepository implements MeRepository {
  MockMeRepository(this._tokens);

  final TokenStore _tokens;

  static const _delay = Duration(milliseconds: 300);

  static const _accounts = <String, (String, String, Role)>{
    'parent': ('김학부모', 'parent@damso.test', Role.parent),
    'newparent': ('박학부모', 'newparent@damso.test', Role.parent),
    'expired': ('최학부모', 'expired@damso.test', Role.parent),
    'refresh': ('정학부모', 'refresh@damso.test', Role.parent),
    'teacher': ('이담임', 'teacher@damso.test', Role.teacher),
    'noclass': ('한교사', 'noclass@damso.test', Role.teacher),
    'admin': ('학교 관리자', 'admin@damso.test', Role.superAdmin),
    'signup-parent': ('가입한 학부모', 'signup@damso.test', Role.parent),
    'signup-teacher': ('가입한 교사', 'signup@damso.test', Role.teacher),
  };

  /// 계정별로 바꾼 이름.
  final _renamed = <String, String>{};

  String get _account => (_tokens.accessToken ?? '').replaceFirst('mock:', '');

  Me _current() {
    final account = _account;
    final (name, email, role) = _accounts[account] ?? _accounts['parent']!;
    return Me(
      userId: '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a',
      name: _renamed[account] ?? name,
      email: email,
      role: role,
    );
  }

  @override
  Future<Me> getMe() async {
    await Future<void>.delayed(_delay);
    return _current();
  }

  @override
  Future<Me> updateName(String name) async {
    await Future<void>.delayed(_delay);
    _renamed[_account] = name;
    return _current();
  }

  @override
  Future<void> withdraw(String password) async {
    await Future<void>.delayed(_delay);
    if (_current().role == Role.superAdmin) {
      throw const AppException(
        message: '권한이 없습니다.',
        code: ErrorCodes.forbidden,
        statusCode: 403,
      );
    }
    if (password != 'damso1234') {
      throw const AppException(
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
        code: ErrorCodes.invalidCredentials,
        statusCode: 401,
      );
    }
    await _tokens.clear();
  }
}
