/// 관리자 화면 전용 입력 검증. 순수 Dart. 통과하면 null, 아니면 안내 문구.
library;

String? validateGrade(int? grade) =>
    grade != null && grade >= 1 && grade <= 6 ? null : '학년은 1~6 중에서 골라 주세요.';

String? validateClassNumber(int? classNumber) =>
    classNumber != null && classNumber >= 1 && classNumber <= 20
    ? null
    : '반은 1~20 중에서 골라 주세요.';

/// 학생 등록 입력 해석 결과.
class StudentNamesInput {
  const StudentNamesInput(this.names, this.error);

  final List<String> names;
  final String? error;
}

/// 줄바꿈으로 구분한 이름 목록 → 앞뒤 공백 제거·빈 줄 제외 → 1~40명, 각 1~20자(data-model §6).
StudentNamesInput parseStudentNames(String raw) {
  final names = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final String? error;
  if (names.isEmpty) {
    error = '학생 이름을 한 줄에 한 명씩 입력해 주세요.';
  } else if (names.length > 40) {
    error = '한 번에 40명까지 등록할 수 있습니다.';
  } else if (names.any((n) => n.runes.length > 20)) {
    error = '이름은 20자까지 입력할 수 있습니다.';
  } else {
    error = null;
  }
  return StudentNamesInput(names, error);
}
