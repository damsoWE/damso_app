import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/admin_repository_provider.dart';
import '../domain/validators.dart';
import 'admin_home_view_model.dart';

class ClassroomNewState {
  const ClassroomNewState({
    this.grade,
    this.classNumber,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final int? grade;
  final int? classNumber;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isValid =>
      validateGrade(grade) == null && validateClassNumber(classNumber) == null;
}

/// ADM-1c 학급 추가.
class ClassroomNewViewModel extends Notifier<ClassroomNewState> {
  @override
  ClassroomNewState build() => const ClassroomNewState();

  void setGrade(int? grade) => state = ClassroomNewState(
    grade: grade,
    classNumber: state.classNumber,
  );

  void setClassNumber(int? classNumber) => state = ClassroomNewState(
    grade: state.grade,
    classNumber: classNumber,
  );

  /// 성공하면 true. 중복(CONFLICT) 등은 서버 안내를 보인다.
  Future<bool> submit() async {
    final s = state;
    if (!s.isValid || s.isSubmitting) return false;
    state = ClassroomNewState(
      grade: s.grade,
      classNumber: s.classNumber,
      isSubmitting: true,
    );
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      await ref
          .read(adminRepositoryProvider)
          .createClassroom(s.grade!, s.classNumber!);
      ref.invalidate(adminHomeViewModelProvider);
      return true;
    } on AppException catch (e) {
      state = ClassroomNewState(
        grade: s.grade,
        classNumber: s.classNumber,
        errorMessage: e.message,
      );
      return false;
    } finally {
      link.close();
    }
  }
}

final classroomNewViewModelProvider =
    NotifierProvider.autoDispose<ClassroomNewViewModel, ClassroomNewState>(
      ClassroomNewViewModel.new,
    );
