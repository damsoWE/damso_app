/// 슈퍼 관리자 화면 모델(data-model §6). 문의 본문·답변은 다루지 않는다(FR-037).
class AdminClassroom {
  const AdminClassroom({
    required this.classroomId,
    required this.grade,
    required this.classNumber,
    required this.homeroomAssigned,
    required this.studentCount,
  });

  final String classroomId;

  /// 1~6
  final int grade;

  /// 1~20
  final int classNumber;

  /// 담임 연결 여부(교사 이름·이메일 없음)
  final bool homeroomAssigned;
  final int studentCount;
}

class AdminStudent {
  const AdminStudent({
    required this.studentId,
    required this.name,
    required this.guardianLinked,
  });

  final String studentId;
  final String name;
  final bool guardianLinked;
}

/// 발행 직후 한 번만 존재하는 코드 원문. 화면 전달만, 보관 금지(FR-035, research R11).
class IssuedInviteCode {
  const IssuedInviteCode({
    required this.inviteCodeId,
    required this.code,
    required this.expiresAt,
  });

  final String inviteCodeId;
  final String code;
  final DateTime expiresAt;
}

enum InviteCodeKind { teacher, parent }

enum InviteCodeState { unused, used, expired, revoked }

/// 발행 현황. 코드 원문은 없다(FR-036).
class InviteCodeStatus {
  const InviteCodeStatus({
    required this.inviteCodeId,
    required this.kind,
    required this.status,
    required this.issuedAt,
    required this.expiresAt,
    this.studentId,
    this.studentName,
    this.usedAt,
  });

  final String inviteCodeId;
  final InviteCodeKind kind;

  /// 학부모 코드일 때만.
  final String? studentId;
  final String? studentName;
  final InviteCodeState status;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
}
