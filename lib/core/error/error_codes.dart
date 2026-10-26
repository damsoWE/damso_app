/// 서버 ErrorCode 문자열(docs/api/openapi.yaml `ErrorCode`).
/// 화면 분기는 [AppException.code] 를 이 상수와 비교해서 한다.
abstract final class ErrorCodes {
  static const invalidInput = 'INVALID_INPUT';
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const conflict = 'CONFLICT';
  static const invalidInviteCode = 'INVALID_INVITE_CODE';
  static const invalidVerificationCode = 'INVALID_VERIFICATION_CODE';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const tooManyAttempts = 'TOO_MANY_ATTEMPTS';
  static const classroomHasTeacher = 'CLASSROOM_HAS_TEACHER';
  static const studentHasGuardian = 'STUDENT_HAS_GUARDIAN';
}
