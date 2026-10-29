import 'models.dart';

/// 슈퍼 관리자 계약(contracts/api-usage.md admin).
abstract class AdminRepository {
  Future<List<AdminClassroom>> listClassrooms();

  Future<AdminClassroom> createClassroom(int grade, int classNumber);

  Future<List<AdminStudent>> listStudents(String classroomId);

  Future<List<AdminStudent>> registerStudents(
    String classroomId,
    List<String> names,
  );

  /// 결과는 화면에 전달만 하고 어디에도 보관하지 않는다.
  Future<IssuedInviteCode> issueTeacherInvite(String classroomId);

  Future<IssuedInviteCode> issueParentInvite(String studentId);

  Future<List<InviteCodeStatus>> listInviteCodes(String classroomId);

  /// 학급별 문의 처리 현황(api-v0.10). 서버 순서(학년·반 순) 그대로, 문의 없는 학급도 0으로 온다.
  Future<List<ClassroomInquiryStatus>> inquiryStatus();
}
