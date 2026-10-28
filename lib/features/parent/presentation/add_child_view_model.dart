import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/cooldown.dart';
import '../data/parent_repository_provider.dart';
import 'children_view_model.dart';

class AddChildState {
  const AddChildState({
    this.isSubmitting = false,
    this.errorMessage,
    this.cooldown = Cooldown.none,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Cooldown cooldown;

  AddChildState copyWith({
    bool? isSubmitting,
    String? Function()? errorMessage,
    Cooldown? cooldown,
  }) => AddChildState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    cooldown: cooldown ?? this.cooldown,
  );
}

/// F1-5 자녀 추가. 실패는 사유를 구분하지 않는 서버 안내(FR-016·FR-027).
class AddChildViewModel extends Notifier<AddChildState> {
  final _timer = CooldownTimer();

  @override
  AddChildState build() {
    ref.onDispose(_timer.cancel);
    return const AddChildState();
  }

  /// 성공하면 true.
  Future<bool> submit(String raw) async {
    if (state.isSubmitting || state.cooldown.isActive) return false;
    final clientError = validateInviteCode(raw);
    if (clientError != null) {
      state = state.copyWith(errorMessage: () => clientError);
      return false;
    }
    state = state.copyWith(isSubmitting: true, errorMessage: () => null);
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      await ref.read(parentRepositoryProvider).linkChild(normalizeInviteCode(raw));
      ref.invalidate(childrenViewModelProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: () => e.message);
      _timer.startIfLimited(e, (c) => state = state.copyWith(cooldown: c));
      return false;
    } finally {
      link.close();
    }
  }
}

final addChildViewModelProvider =
    NotifierProvider.autoDispose<AddChildViewModel, AddChildState>(
      AddChildViewModel.new,
    );
