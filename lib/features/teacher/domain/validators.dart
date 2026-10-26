/// 교사 공개 프로필 검증. 순수 Dart, 글자 수는 코드 포인트. 통과하면 null.
library;

const introductionMaxLength = 60;

String? validateDisplayName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return '표시 이름을 입력해 주세요.';
  if (name.runes.length > 20) return '표시 이름은 20자까지 입력할 수 있습니다.';
  return null;
}

String? validateIntroduction(String raw) =>
    raw.trim().runes.length > introductionMaxLength
    ? '소개는 $introductionMaxLength자까지 입력할 수 있습니다.'
    : null;
