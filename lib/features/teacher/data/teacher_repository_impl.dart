import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/models.dart';
import '../domain/teacher_repository.dart';

/// 실서버 구현. 경로는 docs/api/openapi.yaml(api-v0.3) 그대로.
class TeacherRepositoryImpl implements TeacherRepository {
  TeacherRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TeacherProfile> getProfile() {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/profile');
      return _profile(res.data!);
    });
  }

  @override
  Future<TeacherProfile> updateProfile(TeacherProfile profile) {
    return mapDioErrors(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/v1/teacher/profile',
        data: {
          'displayName': profile.displayName,
          'introduction': profile.introduction,
        },
      );
      return _profile(res.data!);
    });
  }

  @override
  Future<MyClassroom> getMyClassroom() {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/classroom',
      );
      final data = res.data!;
      final c = data['classroom'] as Map<String, dynamic>;
      return MyClassroom(
        classroomId: c['classroomId'] as String,
        grade: c['grade'] as int,
        classNumber: c['classNumber'] as int,
        students: [
          for (final s in (data['students'] as List).cast<Map<String, dynamic>>())
            StudentLink(
              studentId: s['studentId'] as String,
              name: s['name'] as String,
              guardianLinked: s['guardianLinked'] as bool,
            ),
        ],
      );
    });
  }

  static TeacherProfile _profile(Map<String, dynamic> j) => TeacherProfile(
    displayName: j['displayName'] as String,
    introduction: j['introduction'] as String,
  );
}
