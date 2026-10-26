import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/notification_repository_provider.dart';
import '../domain/models.dart';

/// F3-8 입력 상태. Figma 처럼 고른 요일에 같은 시작·종료 시각을 쓴다(요일당 한 구간으로 저장).
class SettingsForm {
  const SettingsForm({
    required this.days,
    required this.start,
    required this.end,
    required this.generalEnabled,
    this.isSaving = false,
    this.errorMessage,
    this.timeError,
    this.saved = false,
  });

  static const defaultStart = TimeOfDayValue(9, 0);
  static const defaultEnd = TimeOfDayValue(18, 0);

  factory SettingsForm.from(NotificationSettings s) => SettingsForm(
    days: {for (final w in s.availability) w.day},
    start: s.availability.isEmpty ? defaultStart : s.availability.first.start,
    end: s.availability.isEmpty ? defaultEnd : s.availability.first.end,
    generalEnabled: s.generalEnabled,
  );

  final Set<DayOfWeek> days;
  final TimeOfDayValue start;
  final TimeOfDayValue end;
  final bool generalEnabled;
  final bool isSaving;
  final String? errorMessage;

  /// 시각 오류(시작 ≥ 종료, 서버 fieldErrors).
  final String? timeError;
  final bool saved;

  /// 요일을 하나도 고르지 않으면 언제든 응답 가능(FR-029).
  bool get alwaysAvailable => days.isEmpty;

  SettingsForm copyWith({
    Set<DayOfWeek>? days,
    TimeOfDayValue? start,
    TimeOfDayValue? end,
    bool? generalEnabled,
    bool? isSaving,
    String? Function()? errorMessage,
    String? Function()? timeError,
    bool? saved,
  }) => SettingsForm(
    days: days ?? this.days,
    start: start ?? this.start,
    end: end ?? this.end,
    generalEnabled: generalEnabled ?? this.generalEnabled,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    timeError: timeError != null ? timeError() : this.timeError,
    saved: saved ?? this.saved,
  );
}

class SettingsViewModel extends AsyncNotifier<SettingsForm> {
  static const startAfterEnd = '시작 시각은 종료 시각보다 빨라야 해요.';

  @override
  Future<SettingsForm> build() async => SettingsForm.from(
    await ref.watch(notificationRepositoryProvider).getSettings(),
  );

  void _edit(SettingsForm Function(SettingsForm) change) {
    final current = state.value;
    if (current == null || current.isSaving) return;
    state = AsyncData(
      change(current).copyWith(
        saved: false,
        errorMessage: () => null,
        timeError: () => null,
      ),
    );
  }

  void toggleDay(DayOfWeek day) => _edit(
    (f) => f.copyWith(
      days: f.days.contains(day) ? ({...f.days}..remove(day)) : {...f.days, day},
    ),
  );

  void setStart(TimeOfDayValue v) => _edit((f) => f.copyWith(start: v));

  void setEnd(TimeOfDayValue v) => _edit((f) => f.copyWith(end: v));

  void setGeneralEnabled(bool v) => _edit((f) => f.copyWith(generalEnabled: v));

  /// 성공하면 true.
  Future<bool> save() async {
    final f = state.value;
    if (f == null || f.isSaving) return false;
    if (!f.alwaysAvailable && f.start.compareTo(f.end) >= 0) {
      state = AsyncData(f.copyWith(timeError: () => startAfterEnd, saved: false));
      return false;
    }
    state = AsyncData(
      f.copyWith(
        isSaving: true,
        errorMessage: () => null,
        timeError: () => null,
        saved: false,
      ),
    );
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      final saved = await ref
          .read(notificationRepositoryProvider)
          .saveSettings(
            NotificationSettings(
              generalEnabled: f.generalEnabled,
              availability: [
                for (final day in DayOfWeek.values)
                  if (f.days.contains(day))
                    AvailabilityWindow(day: day, start: f.start, end: f.end),
              ],
            ),
          );
      state = AsyncData(SettingsForm.from(saved).copyWith(saved: true));
      return true;
    } on AppException catch (e) {
      final fieldError = e.fieldErrors.values.firstOrNull;
      state = AsyncData(
        f.copyWith(
          isSaving: false,
          errorMessage: () => fieldError == null ? e.message : null,
          timeError: () => fieldError,
        ),
      );
      return false;
    } finally {
      link.close();
    }
  }
}

final settingsViewModelProvider =
    AsyncNotifierProvider.autoDispose<SettingsViewModel, SettingsForm>(
      SettingsViewModel.new,
    );
