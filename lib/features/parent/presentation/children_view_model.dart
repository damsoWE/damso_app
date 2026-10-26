import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/parent_repository_provider.dart';
import '../domain/child.dart';

/// 연결된 자녀 목록. 홈·자녀 선택·연결된 자녀·마이페이지가 함께 쓴다.
class ChildrenViewModel extends AsyncNotifier<List<Child>> {
  @override
  Future<List<Child>> build() =>
      ref.watch(parentRepositoryProvider).listChildren();

  void refresh() => ref.invalidateSelf();
}

final childrenViewModelProvider =
    AsyncNotifierProvider.autoDispose<ChildrenViewModel, List<Child>>(
      ChildrenViewModel.new,
    );
