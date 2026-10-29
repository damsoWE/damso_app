import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../data/admin_repository_provider.dart';
import '../domain/models.dart';
import 'admin_home_view_model.dart';

/// 코드를 발행할 대상. 재발행 확인 화면(ADM-6)에 extra 로 넘긴다(URL 에 이름을 넣지 않음).
sealed class InviteTarget {
  const InviteTarget(this.classroomId);

  final String classroomId;
}

final class TeacherInviteTarget extends InviteTarget {
  const TeacherInviteTarget(super.classroomId);
}

final class ParentInviteTarget extends InviteTarget {
  const ParentInviteTarget(
    super.classroomId, {
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;
}

sealed class IssueResult {
  const IssueResult();
}

final class Issued extends IssueResult {
  const Issued(this.code);

  final IssuedInviteCode code;
}

final class IssueFailed extends IssueResult {
  const IssueFailed(this.message);

  final String message;
}

/// 이미 발행 요청이 진행 중이라 이번 요청은 보내지 않았다(중복 발행 방지).
final class IssueBusy extends IssueResult {
  const IssueBusy();
}

/// 발행 완료 화면(ADM-3/3t)에 extra 로만 넘기는 값. Provider·저장소에 보관하지 않는다.
class IssuedInviteArgs {
  const IssuedInviteArgs({required this.code, required this.target});

  final IssuedInviteCode code;
  final InviteTarget target;
}

/// 학급 상세 상태. 코드 원문은 담지 않는다(SC-006).
class ClassroomDetail {
  const ClassroomDetail({
    required this.classroom,
    required this.students,
    required this.teacherCodeUnused,
    required this.studentsWithUnusedCode,
    this.issuing = false,
  });

  final AdminClassroom classroom;
  final List<AdminStudent> students;

  /// 미사용 교사 코드가 있으면 발행 대신 재발행(확인 필요).
  final bool teacherCodeUnused;
  final Set<String> studentsWithUnusedCode;

  /// 코드 발행 요청이 진행 중인지. 버튼을 막는 데만 쓴다.
  final bool issuing;

  ClassroomDetail copyWith({bool? issuing}) => ClassroomDetail(
    classroom: classroom,
    students: students,
    teacherCodeUnused: teacherCodeUnused,
    studentsWithUnusedCode: studentsWithUnusedCode,
    issuing: issuing ?? this.issuing,
  );
}

/// ADM-1 학급 상세 · ADM-2 교사 초대코드 발행.
class ClassroomDetailViewModel extends AsyncNotifier<ClassroomDetail> {
  ClassroomDetailViewModel(this.classroomId);

  final String classroomId;

  /// 발행 요청 진행 중 여부. 새 코드가 이전 코드를 무효로 만들므로 동시에 두 번 보내지 않는다.
  bool _issuing = false;

  @override
  Future<ClassroomDetail> build() async {
    final repo = ref.watch(adminRepositoryProvider);
    final results = await Future.wait<Object>([
      repo.listClassrooms(),
      repo.listStudents(classroomId),
      repo.listInviteCodes(classroomId),
    ]);
    final classrooms = results[0] as List<AdminClassroom>;
    final students = results[1] as List<AdminStudent>;
    final codes = results[2] as List<InviteCodeStatus>;
    final classroom = classrooms.where((c) => c.classroomId == classroomId);
    if (classroom.isEmpty) {
      throw const AppException(
        message: '요청한 대상을 찾을 수 없습니다.',
        code: ErrorCodes.notFound,
        statusCode: 404,
      );
    }
    final unused = codes.where((c) => c.status == InviteCodeState.unused);
    return ClassroomDetail(
      classroom: classroom.first,
      students: students,
      teacherCodeUnused: unused.any((c) => c.kind == InviteCodeKind.teacher),
      studentsWithUnusedCode: {
        for (final c in unused)
          if (c.studentId != null) c.studentId!,
      },
    );
  }

  void refresh() => ref.invalidateSelf();

  /// 발행·재발행. 결과 코드는 돌려주기만 하고 상태에 담지 않는다.
  /// 실패(예: 그사이 교사가 연결돼 409)해도 현황이 바뀌었을 수 있으므로 다시 불러온다.
  /// 이미 요청 중이면 보내지 않고 [IssueBusy] 를 돌려준다.
  Future<IssueResult> issue(InviteTarget target) async {
    if (_issuing) return const IssueBusy();
    _issuing = true;
    final repo = ref.read(adminRepositoryProvider);
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(issuing: true));
    try {
      final code = switch (target) {
        TeacherInviteTarget() => await repo.issueTeacherInvite(target.classroomId),
        ParentInviteTarget(:final studentId) => await repo.issueParentInvite(
          studentId,
        ),
      };
      return Issued(code);
    } on AppException catch (e) {
      return IssueFailed(e.message);
    } finally {
      _issuing = false;
      ref.invalidateSelf(); // 다시 불러오면서 issuing 도 false 로 돌아간다.
      ref.invalidate(adminHomeViewModelProvider);
      link.close();
    }
  }
}

final classroomDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<ClassroomDetailViewModel, ClassroomDetail, String>(
      ClassroomDetailViewModel.new,
    );
