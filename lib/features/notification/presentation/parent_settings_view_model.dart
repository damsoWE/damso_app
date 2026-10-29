import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/parent_notification_repository_provider.dart';

/// F2-8 알림 설정 상태. 토글을 켜고 끄면 바로 저장하고, 서버가 확정한 값으로만 바꾼다(FR-023).
class ParentSettingsState {
  const ParentSettingsState({
    required this.answerNotifyEnabled,
    this.saving = false,
    this.errorMessage,
  });

  final bool answerNotifyEnabled;
  final bool saving;
  final String? errorMessage;
}

class ParentSettingsViewModel extends AsyncNotifier<ParentSettingsState> {
  @override
  Future<ParentSettingsState> build() async {
    final s = await ref.watch(parentNotificationRepositoryProvider).getSettings();
    return ParentSettingsState(answerNotifyEnabled: s.answerNotifyEnabled);
  }

  /// 저장 중에는 다시 누를 수 없다. 실패하면 원래 값을 두고 서버 안내를 보인다.
  Future<void> setAnswerNotify(bool enabled) async {
    final current = state.value;
    if (current == null || current.saving) return;
    state = AsyncData(
      ParentSettingsState(answerNotifyEnabled: current.answerNotifyEnabled, saving: true),
    );
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다.
    try {
      final saved = await ref.read(parentNotificationRepositoryProvider).saveSettings(enabled);
      state = AsyncData(ParentSettingsState(answerNotifyEnabled: saved.answerNotifyEnabled));
    } on AppException catch (e) {
      state = AsyncData(
        ParentSettingsState(
          answerNotifyEnabled: current.answerNotifyEnabled,
          errorMessage: e.message,
        ),
      );
    } finally {
      link.close();
    }
  }
}

final parentSettingsViewModelProvider =
    AsyncNotifierProvider.autoDispose<ParentSettingsViewModel, ParentSettingsState>(
      ParentSettingsViewModel.new,
    );
