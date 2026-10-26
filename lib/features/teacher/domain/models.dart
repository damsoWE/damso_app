/// 교사 기능 모델(data-model §5). 다른 기능의 모델을 import 하지 않는다.
class TeacherProfile {
  const TeacherProfile({required this.displayName, required this.introduction});

  /// 1~20자
  final String displayName;

  /// 0~60자
  final String introduction;
}

/// 학생별 학부모 연결 여부. 학부모 이름·이메일은 없다(FR-030).
class StudentLink {
  const StudentLink({
    required this.studentId,
    required this.name,
    required this.guardianLinked,
  });

  final String studentId;
  final String name;
  final bool guardianLinked;
}

class MyClassroom {
  const MyClassroom({
    required this.classroomId,
    required this.grade,
    required this.classNumber,
    required this.students,
  });

  final String classroomId;
  final int grade;
  final int classNumber;
  final List<StudentLink> students;
}
