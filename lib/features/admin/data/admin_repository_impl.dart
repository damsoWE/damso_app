import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/admin_repository.dart';
import '../domain/models.dart';

/// 실서버 구현. 경로는 docs/api/openapi.yaml(api-v0.3) 그대로.
class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<AdminClassroom>> listClassrooms() {
    return mapDioErrors(() async {
      final res = await _dio.get<List<dynamic>>('/api/v1/admin/classrooms');
      return res.data!.cast<Map<String, dynamic>>().map(_classroom).toList();
    });
  }

  @override
  Future<AdminClassroom> createClassroom(int grade, int classNumber) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/admin/classrooms',
        data: {'grade': grade, 'classNumber': classNumber},
      );
      return _classroom(res.data!);
    });
  }

  @override
  Future<List<AdminStudent>> listStudents(String classroomId) {
    return mapDioErrors(() async {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/admin/classrooms/$classroomId/students',
      );
      return res.data!.cast<Map<String, dynamic>>().map(_student).toList();
    });
  }

  @override
  Future<List<AdminStudent>> registerStudents(
    String classroomId,
    List<String> names,
  ) {
    return mapDioErrors(() async {
      final res = await _dio.post<List<dynamic>>(
        '/api/v1/admin/classrooms/$classroomId/students',
        data: {'names': names},
      );
      return res.data!.cast<Map<String, dynamic>>().map(_student).toList();
    });
  }

  @override
  Future<IssuedInviteCode> issueTeacherInvite(String classroomId) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/admin/classrooms/$classroomId/teacher-invite',
      );
      return _issued(res.data!);
    });
  }

  @override
  Future<IssuedInviteCode> issueParentInvite(String studentId) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/admin/students/$studentId/parent-invite',
      );
      return _issued(res.data!);
    });
  }

  @override
  Future<List<InviteCodeStatus>> listInviteCodes(String classroomId) {
    return mapDioErrors(() async {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/admin/invite-codes',
        queryParameters: {'classroomId': classroomId},
      );
      return res.data!.cast<Map<String, dynamic>>().map(_status).toList();
    });
  }

  static AdminClassroom _classroom(Map<String, dynamic> j) => AdminClassroom(
    classroomId: j['classroomId'] as String,
    grade: j['grade'] as int,
    classNumber: j['classNumber'] as int,
    homeroomAssigned: j['homeroomAssigned'] as bool,
    studentCount: j['studentCount'] as int,
  );

  static AdminStudent _student(Map<String, dynamic> j) => AdminStudent(
    studentId: j['studentId'] as String,
    name: j['name'] as String,
    guardianLinked: j['guardianLinked'] as bool,
  );

  static IssuedInviteCode _issued(Map<String, dynamic> j) => IssuedInviteCode(
    inviteCodeId: j['inviteCodeId'] as String,
    code: j['code'] as String,
    expiresAt: _time(j['expiresAt'])!,
  );

  static InviteCodeStatus _status(Map<String, dynamic> j) => InviteCodeStatus(
    inviteCodeId: j['inviteCodeId'] as String,
    kind: j['kind'] == 'TEACHER' ? InviteCodeKind.teacher : InviteCodeKind.parent,
    studentId: j['studentId'] as String?,
    studentName: j['studentName'] as String?,
    status: switch (j['status']) {
      'USED' => InviteCodeState.used,
      'EXPIRED' => InviteCodeState.expired,
      'REVOKED' => InviteCodeState.revoked,
      _ => InviteCodeState.unused,
    },
    issuedAt: _time(j['issuedAt'])!,
    expiresAt: _time(j['expiresAt'])!,
    usedAt: _time(j['usedAt']),
  );

  static DateTime? _time(Object? raw) =>
      raw is String ? DateTime.parse(raw).toLocal() : null;
}
