import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/child.dart';
import '../domain/parent_repository.dart';

/// 실서버 구현. 경로는 docs/api/openapi.yaml(api-v0.3) 그대로.
class ParentRepositoryImpl implements ParentRepository {
  ParentRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Child>> listChildren() {
    return mapDioErrors(() async {
      final res = await _dio.get<List<dynamic>>('/api/v1/parent/children');
      return res.data!.cast<Map<String, dynamic>>().map(_child).toList();
    });
  }

  @override
  Future<Child> linkChild(String inviteCode) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/parent/children',
        data: {'inviteCode': inviteCode},
      );
      return _child(res.data!);
    });
  }

  static Child _child(Map<String, dynamic> j) {
    final c = j['classroom'] as Map<String, dynamic>;
    final t = j['teacher'] as Map<String, dynamic>?;
    return Child(
      studentId: j['studentId'] as String,
      studentName: j['studentName'] as String,
      classroom: ClassroomRef(
        classroomId: c['classroomId'] as String,
        grade: c['grade'] as int,
        classNumber: c['classNumber'] as int,
      ),
      teacher: t == null
          ? null
          : TeacherPublicProfile(
              displayName: t['displayName'] as String,
              introduction: t['introduction'] as String,
            ),
    );
  }
}
