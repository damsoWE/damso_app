import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/admin_repository_provider.dart';
import '../domain/models.dart';
import '../domain/validators.dart';
import 'admin_home_view_model.dart';
import 'classroom_detail_view_model.dart';

class StudentsNewState {
  const StudentsNewState({
    this.isSubmitting = false,
    this.errorMessage,
    this.registered,
  });

  final bool isSubmitting;
  final String? errorMessage;

  /// 등록 완료(ADM-5a) 후의 명단. null 이면 입력 단계(ADM-5).
  final List<AdminStudent>? registered;
}

/// ADM-5 학생 등록 · ADM-5a 등록 완료.
class StudentsNewViewModel extends Notifier<StudentsNewState> {
  StudentsNewViewModel(this.classroomId);

  final String classroomId;

  @override
  StudentsNewState build() => const StudentsNewState();

  Future<void> submit(String raw) async {
    if (state.isSubmitting) return;
    final input = parseStudentNames(raw);
    if (input.error != null) {
      state = StudentsNewState(errorMessage: input.error);
      return;
    }
    state = const StudentsNewState(isSubmitting: true);
    try {
      final added = await ref
          .read(adminRepositoryProvider)
          .registerStudents(classroomId, input.names);
      ref.invalidate(classroomDetailViewModelProvider(classroomId));
      ref.invalidate(adminHomeViewModelProvider);
      state = StudentsNewState(registered: added);
    } on AppException catch (e) {
      state = StudentsNewState(errorMessage: e.message);
    }
  }
}

final studentsNewViewModelProvider = NotifierProvider.autoDispose
    .family<StudentsNewViewModel, StudentsNewState, String>(
      StudentsNewViewModel.new,
    );
