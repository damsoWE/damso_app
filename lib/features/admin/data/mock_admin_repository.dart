import 'dart:math';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../domain/admin_repository.dart';
import '../domain/models.dart';

/// mock 구현(quickstart "관리자"). 상태는 메모리 전용이고 재시작하면 초기값으로 돌아간다.
/// 초기 데이터: 3학년 2반(담임 있음, 김하나·박서준·이도윤), 1학년 1반(담임 없음, 학생 0명).
class MockAdminRepository implements AdminRepository {
  MockAdminRepository() {
    final now = DateTime.now();
    final c32 = _MockClassroom(_uuid(), 3, 2, homeroomAssigned: true);
    final c11 = _MockClassroom(_uuid(), 1, 1);
    _classrooms.addAll([c32, c11]);
    final kim = _MockStudent(_uuid(), c32.id, '김하나', guardianLinked: true);
    final park = _MockStudent(_uuid(), c32.id, '박서준');
    final lee = _MockStudent(_uuid(), c32.id, '이도윤');
    _students.addAll([kim, park, lee]);
    _codes.addAll([
      _MockCode(
        _uuid(),
        c32.id,
        InviteCodeKind.teacher,
        status: InviteCodeState.used,
        issuedAt: now.subtract(const Duration(days: 10)),
        usedAt: now.subtract(const Duration(days: 9)),
      ),
      _MockCode(
        _uuid(),
        c32.id,
        InviteCodeKind.parent,
        student: kim,
        status: InviteCodeState.used,
        issuedAt: now.subtract(const Duration(days: 5)),
        usedAt: now.subtract(const Duration(days: 4)),
      ),
      _MockCode(
        _uuid(),
        c32.id,
        InviteCodeKind.parent,
        student: park,
        issuedAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  static const _delay = Duration(milliseconds: 300);
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final _random = Random();

  final _classrooms = <_MockClassroom>[];
  final _students = <_MockStudent>[];
  final _codes = <_MockCode>[];

  static String _uuid() {
    String hex(int n) => List.generate(
      n,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  static String _newCode() =>
      List.generate(10, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();

  static const _notFound = AppException(
    message: '요청한 대상을 찾을 수 없습니다.',
    code: ErrorCodes.notFound,
    statusCode: 404,
  );

  _MockClassroom _classroom(String id) => _classrooms.firstWhere(
    (c) => c.id == id,
    orElse: () => throw _notFound,
  );

  AdminClassroom _toClassroom(_MockClassroom c) => AdminClassroom(
    classroomId: c.id,
    grade: c.grade,
    classNumber: c.classNumber,
    homeroomAssigned: c.homeroomAssigned,
    studentCount: _students.where((s) => s.classroomId == c.id).length,
  );

  static AdminStudent _toStudent(_MockStudent s) => AdminStudent(
    studentId: s.id,
    name: s.name,
    guardianLinked: s.guardianLinked,
  );

  @override
  Future<List<AdminClassroom>> listClassrooms() async {
    await Future<void>.delayed(_delay);
    return _classrooms.map(_toClassroom).toList();
  }

  @override
  Future<AdminClassroom> createClassroom(int grade, int classNumber) async {
    await Future<void>.delayed(_delay);
    if (_classrooms.any((c) => c.grade == grade && c.classNumber == classNumber)) {
      throw const AppException(
        message: '이미 등록된 학급입니다.',
        code: ErrorCodes.conflict,
        statusCode: 409,
      );
    }
    final c = _MockClassroom(_uuid(), grade, classNumber);
    _classrooms.add(c);
    return _toClassroom(c);
  }

  @override
  Future<List<AdminStudent>> listStudents(String classroomId) async {
    await Future<void>.delayed(_delay);
    _classroom(classroomId);
    return _students
        .where((s) => s.classroomId == classroomId)
        .map(_toStudent)
        .toList();
  }

  @override
  Future<List<AdminStudent>> registerStudents(
    String classroomId,
    List<String> names,
  ) async {
    await Future<void>.delayed(_delay);
    _classroom(classroomId);
    final added = [for (final n in names) _MockStudent(_uuid(), classroomId, n)];
    _students.addAll(added);
    return added.map(_toStudent).toList();
  }

  @override
  Future<IssuedInviteCode> issueTeacherInvite(String classroomId) async {
    await Future<void>.delayed(_delay);
    final c = _classroom(classroomId);
    if (c.homeroomAssigned) {
      throw const AppException(
        message: '이미 담임이 연결된 학급입니다.',
        code: ErrorCodes.classroomHasTeacher,
        statusCode: 409,
      );
    }
    return _issue(c.id, InviteCodeKind.teacher, null);
  }

  @override
  Future<IssuedInviteCode> issueParentInvite(String studentId) async {
    await Future<void>.delayed(_delay);
    final s = _students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => throw _notFound,
    );
    if (s.guardianLinked) {
      throw const AppException(
        message: '이미 보호자가 연결된 학생입니다.',
        code: ErrorCodes.studentHasGuardian,
        statusCode: 409,
      );
    }
    return _issue(s.classroomId, InviteCodeKind.parent, s);
  }

  /// 같은 대상의 이전 미사용 코드는 즉시 무효(REVOKED)가 된다.
  IssuedInviteCode _issue(
    String classroomId,
    InviteCodeKind kind,
    _MockStudent? student,
  ) {
    for (final old in _codes) {
      if (old.classroomId == classroomId &&
          old.kind == kind &&
          old.student?.id == student?.id &&
          old.status == InviteCodeState.unused) {
        old.status = InviteCodeState.revoked;
      }
    }
    final now = DateTime.now();
    final entry = _MockCode(
      _uuid(),
      classroomId,
      kind,
      student: student,
      issuedAt: now,
    );
    _codes.add(entry);
    return IssuedInviteCode(
      inviteCodeId: entry.id,
      code: _newCode(), // 원문은 mock 에도 남기지 않는다
      expiresAt: entry.expiresAt,
    );
  }

  @override
  Future<List<InviteCodeStatus>> listInviteCodes(String classroomId) async {
    await Future<void>.delayed(_delay);
    _classroom(classroomId);
    return [
      for (final c in _codes.where((c) => c.classroomId == classroomId))
        InviteCodeStatus(
          inviteCodeId: c.id,
          kind: c.kind,
          studentId: c.student?.id,
          studentName: c.student?.name,
          status: c.status,
          issuedAt: c.issuedAt,
          expiresAt: c.expiresAt,
          usedAt: c.usedAt,
        ),
    ];
  }
}

class _MockClassroom {
  _MockClassroom(
    this.id,
    this.grade,
    this.classNumber, {
    this.homeroomAssigned = false,
  });

  final String id;
  final int grade;
  final int classNumber;
  final bool homeroomAssigned;
}

class _MockStudent {
  _MockStudent(this.id, this.classroomId, this.name, {this.guardianLinked = false});

  final String id;
  final String classroomId;
  final String name;
  final bool guardianLinked;
}

class _MockCode {
  _MockCode(
    this.id,
    this.classroomId,
    this.kind, {
    required this.issuedAt,
    this.student,
    this.status = InviteCodeState.unused,
    this.usedAt,
  }) : expiresAt = issuedAt.add(const Duration(hours: 24));

  final String id;
  final String classroomId;
  final InviteCodeKind kind;
  final _MockStudent? student;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  InviteCodeState status;
}
