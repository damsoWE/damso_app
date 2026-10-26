import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository_provider.dart';
import '../domain/models.dart';

/// ADM-1a/1b 학급 목록. 학년·반 순으로 정렬한다.
class AdminHomeViewModel extends AsyncNotifier<List<AdminClassroom>> {
  @override
  Future<List<AdminClassroom>> build() async {
    final list = await ref.watch(adminRepositoryProvider).listClassrooms();
    return [...list]..sort(
      (a, b) => a.grade != b.grade
          ? a.grade.compareTo(b.grade)
          : a.classNumber.compareTo(b.classNumber),
    );
  }

  void refresh() => ref.invalidateSelf();
}

final adminHomeViewModelProvider =
    AsyncNotifierProvider.autoDispose<AdminHomeViewModel, List<AdminClassroom>>(
      AdminHomeViewModel.new,
    );
