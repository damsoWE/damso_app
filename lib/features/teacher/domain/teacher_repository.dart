import 'models.dart';

/// 교사 계약(contracts/api-usage.md teacher).
abstract class TeacherRepository {
  Future<TeacherProfile> getProfile();

  Future<TeacherProfile> updateProfile(TeacherProfile profile);

  /// 담당 학급이 없으면 FORBIDDEN.
  Future<MyClassroom> getMyClassroom();
}
