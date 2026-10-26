import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/session/role.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/models.dart';

/// mock 구현(서버 불필요). 데모 입력표: specs/001-foundation-auth-signup/quickstart.md.
/// 로그인 성공 시 accessToken 에 `mock:<이메일 @앞부분>` 만 넣는다(보안 저장소에는 쓰지 않음).
/// 다른 기능의 mock 은 이 값으로 데모 계정을 구분한다. 상태는 메모리 전용.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._tokens);

  final TokenStore _tokens;

  static const _password = 'damso1234';
  static const _delay = Duration(milliseconds: 300);

  static const _accounts = {
    'parent@damso.test': Role.parent,
    'newparent@damso.test': Role.parent,
    'expired@damso.test': Role.parent,
    'refresh@damso.test': Role.parent,
    'teacher@damso.test': Role.teacher,
    'noclass@damso.test': Role.teacher,
    'admin@damso.test': Role.superAdmin,
  };

  static const _inviteCodes = {
    'PARENTCDE2': InviteRole.parent,
    'TEACHERCD2': InviteRole.teacher,
  };

  /// 대기 중인 가입의 역할(인증 성공 시 이 역할로 로그인).
  InviteRole? _pendingRole;

  static AppException _locked(int seconds) => AppException(
    message: '잠시 후 다시 시도해 주세요.',
    code: ErrorCodes.tooManyAttempts,
    statusCode: 429,
    retryAfter: Duration(seconds: seconds),
  );

  static const _invalidInvite = AppException(
    message: '코드를 확인해 주세요.',
    code: ErrorCodes.invalidInviteCode,
    statusCode: 400,
  );

  static const _invalidVerification = AppException(
    message: '인증 코드가 올바르지 않습니다.',
    code: ErrorCodes.invalidVerificationCode,
    statusCode: 400,
  );

  InviteRole _checkCode(String code) {
    if (code == 'ZZZZZZZZZZ') throw _locked(600);
    final role = _inviteCodes[code];
    if (role == null) throw _invalidInvite;
    return role;
  }

  @override
  Future<InviteRole> checkInviteCode({
    required String code,
    required String email,
  }) async {
    await Future<void>.delayed(_delay);
    _checkEmail(email);
    return _checkCode(code);
  }

  /// `invalid@damso.test` 는 서버 필드 오류(INVALID_INPUT)를 재현한다(US1-7).
  static void _checkEmail(String email) {
    if (email == 'invalid@damso.test') {
      throw const AppException(
        message: '입력값이 올바르지 않습니다.',
        code: ErrorCodes.invalidInput,
        statusCode: 400,
        fieldErrors: {'email': '사용할 수 없는 이메일 형식입니다.'},
      );
    }
  }

  @override
  Future<PendingSignup> startSignup(SignupForm form) async {
    await Future<void>.delayed(_delay);
    _checkEmail(form.email);
    _pendingRole = _checkCode(form.inviteCode);
    return const PendingSignup(
      pendingSignupId: 'mock-pending',
      codeExpiresIn: Duration(minutes: 10),
    );
  }

  @override
  Future<AuthResult> verifySignup(String pendingSignupId, String code) async {
    await Future<void>.delayed(_delay);
    switch (code) {
      case '123456':
        final role = _pendingRole == InviteRole.teacher
            ? Role.teacher
            : Role.parent;
        _pendingRole = null;
        _tokens.accessToken = 'mock:signup-${role.name}';
        return AuthResult(role: role);
      case '999999': // 그사이 초대 코드가 재발행·만료됨
        throw _invalidInvite;
      case '000000':
        throw _locked(600);
      default:
        throw _invalidVerification;
    }
  }

  @override
  Future<void> resendSignupCode(String pendingSignupId) async {
    await Future<void>.delayed(_delay);
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_delay);
    final normalized = email.trim().toLowerCase();
    if (normalized == 'wait@damso.test') throw _locked(30);
    final role = _accounts[normalized];
    if (role == null || password != _password) {
      throw const AppException(
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
        code: ErrorCodes.invalidCredentials,
        statusCode: 401,
      );
    }
    _tokens.accessToken = 'mock:${normalized.split('@').first}';
    return AuthResult(role: role);
  }

  /// mock 은 세션을 기기에 저장하지 않으므로 재시작하면 항상 시작 화면이다.
  @override
  Future<Role?> restoreSession() async => null;

  @override
  Future<void> logout() async {
    await Future<void>.delayed(_delay);
    await _tokens.clear();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future<void>.delayed(_delay);
  }

  @override
  Future<void> verifyPasswordResetCode(String email, String code) async {
    await Future<void>.delayed(_delay);
    _checkResetCode(code);
  }

  @override
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String newPassword,
  ) async {
    await Future<void>.delayed(_delay);
    _checkResetCode(code);
    await _tokens.clear();
  }

  /// 재설정에서 `999999` 는 일반 INVALID_VERIFICATION_CODE 다(INVALID_INVITE_CODE 는 가입 전용).
  void _checkResetCode(String code) {
    if (code == '123456') return;
    if (code == '000000') throw _locked(600);
    throw _invalidVerification;
  }
}
