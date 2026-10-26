/// 학부모 기준 자녀 모델(data-model §4). 담임 이메일은 없다(원칙 I).
class ClassroomRef {
  const ClassroomRef({
    required this.classroomId,
    required this.grade,
    required this.classNumber,
  });

  final String classroomId;
  final int grade;
  final int classNumber;
}

class TeacherPublicProfile {
  const TeacherPublicProfile({
    required this.displayName,
    required this.introduction,
  });

  final String displayName;
  final String introduction;
}

class Child {
  const Child({
    required this.studentId,
    required this.studentName,
    required this.classroom,
    this.teacher,
  });

  final String studentId;
  final String studentName;
  final ClassroomRef classroom;

  /// null 이면 담임이 아직 없다.
  final TeacherPublicProfile? teacher;
}
