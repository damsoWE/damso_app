import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/child.dart';
import 'children_view_model.dart';

class ParentHomeState {
  const ParentHomeState({required this.children, required this.selected});

  final List<Child> children;

  /// 홈에 보이는 자녀. 자녀가 없으면 null.
  final Child? selected;
}

/// F2-1 학부모 홈. 선택한 자녀는 화면 상태(메모리)이고 기본값은 첫 번째 자녀다.
class ParentHomeViewModel extends AsyncNotifier<ParentHomeState> {
  String? _selectedId;

  @override
  Future<ParentHomeState> build() async =>
      _compose(await ref.watch(childrenViewModelProvider.future));

  ParentHomeState _compose(List<Child> children) {
    final selected = children.where((c) => c.studentId == _selectedId);
    return ParentHomeState(
      children: children,
      selected: selected.isNotEmpty
          ? selected.first
          : (children.isEmpty ? null : children.first),
    );
  }

  void select(String studentId) {
    _selectedId = studentId;
    final current = state.value;
    if (current != null) state = AsyncData(_compose(current.children));
  }

  void refresh() => ref.invalidate(childrenViewModelProvider);
}

final parentHomeViewModelProvider =
    AsyncNotifierProvider.autoDispose<ParentHomeViewModel, ParentHomeState>(
      ParentHomeViewModel.new,
    );
