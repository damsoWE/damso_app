import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/form_layout.dart';
import '../../../core/widgets/system_notice.dart';
import '../../../core/push/push_messaging.dart';
import '../domain/models.dart';
import 'device_registrar.dart';
import 'settings_view_model.dart';

/// F3-8 응답 가능 시간·알림 설정 (Figma 224-1287). 긴급 알림은 끄는 항목이 없다(FR-028).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const alwaysAvailableGuide = '요일을 고르지 않으면 언제든 응답 가능으로 봐요.';
  static const deferredGuide = '시간 밖의 문의도 바로 접수돼요. 알림만 다음 응답 가능 시간에 보내 드려요.';
  static const mixedTimesGuide =
      '요일마다 다른 시각이 저장돼 있어요. 시각을 바꾸면 고른 요일 모두 같은 시각이 돼요.';
  static const urgentAlwaysOn = '긴급 문의 알림은 시간과 관계없이 항상 보내요. 끌 수 없어요.';

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDayValue current,
    void Function(TimeOfDayValue) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour % 24, minute: current.minute),
    );
    if (picked != null) onPicked(TimeOfDayValue(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(settingsViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('응답 가능 시간')),
      body: AsyncView(
        value: ref.watch(settingsViewModelProvider),
        onRetry: () => ref.invalidate(settingsViewModelProvider),
        data: (f) => SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const Text('요일', style: AppTextStyles.smallStrong),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final day in DayOfWeek.values)
                          FilterChip(
                            label: Text(day.label),
                            selected: f.days.contains(day),
                            onSelected: (_) => vm.toggleDay(day),
                          ),
                      ],
                    ),
                    if (f.alwaysAvailable)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(alwaysAvailableGuide, style: AppTextStyles.small),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('시간', style: AppTextStyles.smallStrong),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: '시작',
                            value: f.start,
                            enabled: !f.alwaysAvailable,
                            onTap: () => _pickTime(context, f.start, vm.setStart),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _TimeField(
                            label: '종료',
                            value: f.end,
                            enabled: !f.alwaysAvailable,
                            onTap: () => _pickTime(context, f.end, vm.setEnd),
                          ),
                        ),
                      ],
                    ),
                    if (f.mixedTimes && !f.timesEdited)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(mixedTimesGuide, style: AppTextStyles.small),
                      ),
                    MessageText(f.timeError),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('일반 문의 알림'),
                      subtitle: const Text('응답 가능 시간에만 알려 드려요'),
                      value: f.generalEnabled,
                      onChanged: vm.setGeneralEnabled,
                    ),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    const SystemNotice(deferredGuide, icon: Icons.info_outline),
                    const SizedBox(height: AppSpacing.sm),
                    const SystemNotice(urgentAlwaysOn, icon: Icons.warning_amber_outlined),
                    const _DevicePermissionNotice(),
                    MessageText(f.errorMessage),
                    if (f.saved) const MessageText('저장했어요.', isError: false),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SubmitButton(
                    label: '저장',
                    isLoading: f.isSaving,
                    onPressed: vm.save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final TimeOfDayValue value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          border: const OutlineInputBorder(),
        ),
        child: Text(value.format(), style: AppTextStyles.body),
      ),
    );
  }
}

/// 기기 알림 권한이 꺼져 있으면 안내한다(FR-031a). 알림 기능이 없는 실행이면 그리지 않는다.
class _DevicePermissionNotice extends ConsumerWidget {
  const _DevicePermissionNotice();

  static const text = '기기 알림이 꺼져 있습니다. 기기 설정에서 담소 알림을 켜 주세요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(pushPermissionProvider).value != PushPermission.denied) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      child: SystemNotice(text, icon: Icons.notifications_off_outlined),
    );
  }
}
