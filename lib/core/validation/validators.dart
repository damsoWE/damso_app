/// 두 개 이상 기능(auth·parent·me)이 쓰는 입력 검증. 순수 Dart.
/// 각 함수는 통과하면 null, 아니면 사용자 안내 문구를 돌려준다.
/// 글자 수는 코드 포인트(`runes.length`)로 센다 — 서버와 같은 기준(research R9).
/// 서버 fieldErrors 가 오면 이 결과보다 우선한다.
library;

final _inviteCodePattern = RegExp(r'^[A-HJKMNP-Z2-9]{10}$');
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _letter = RegExp(r'[A-Za-z]');
final _digit = RegExp(r'[0-9]');
final _sixDigits = RegExp(r'^[0-9]{6}$');
final _whitespace = RegExp(r'\s');

/// 공백 제거 + 대문자 변환.
String normalizeInviteCode(String raw) =>
    raw.replaceAll(_whitespace, '').toUpperCase();

String? validateInviteCode(String raw) {
  final code = normalizeInviteCode(raw);
  if (code.isEmpty) return '초대 코드를 입력해 주세요.';
  if (!_inviteCodePattern.hasMatch(code)) return '초대 코드 10자리를 확인해 주세요.';
  return null;
}

String? validateName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return '이름을 입력해 주세요.';
  if (name.runes.length > 20) return '이름은 20자까지 입력할 수 있습니다.';
  return null;
}

String? validateEmail(String raw) {
  final email = raw.trim();
  if (email.isEmpty) return '이메일을 입력해 주세요.';
  if (email.runes.length > 254 || !_emailPattern.hasMatch(email)) {
    return '이메일 형식을 확인해 주세요.';
  }
  return null;
}

/// 가입·재설정용 새 비밀번호.
String? validateNewPassword(String raw) {
  final length = raw.runes.length;
  if (length < 8 ||
      length > 64 ||
      !_letter.hasMatch(raw) ||
      !_digit.hasMatch(raw)) {
    return '영문과 숫자를 포함해 8~64자로 입력해 주세요.';
  }
  return null;
}

/// 로그인·탈퇴 확인용 현재 비밀번호.
String? validateCurrentPassword(String raw) {
  if (raw.isEmpty) return '비밀번호를 입력해 주세요.';
  if (raw.runes.length > 64) return '비밀번호는 64자까지 입력할 수 있습니다.';
  return null;
}

String normalizeSixDigitCode(String raw) => raw.replaceAll(_whitespace, '');

String? validateSixDigitCode(String raw) =>
    _sixDigits.hasMatch(normalizeSixDigitCode(raw)) ? null : '6자리 숫자를 입력해 주세요.';
