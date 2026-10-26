import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/teacher_repository_provider.dart';
import '../domain/models.dart';

/// F3-10 학부모 연결 현황. 마이페이지의 담당 학급 표시도 이 값을 쓴다.
class LinksViewModel extends AsyncNotifier<MyClassroom> {
  @override
  Future<MyClassroom> build() =>
      ref.watch(teacherRepositoryProvider).getMyClassroom();

  void refresh() => ref.invalidateSelf();
}

final linksViewModelProvider =
    AsyncNotifierProvider.autoDispose<LinksViewModel, MyClassroom>(
      LinksViewModel.new,
    );
