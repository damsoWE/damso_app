import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/form_layout.dart';
import '../../../core/widgets/system_notice.dart';
import 'parent_settings_view_model.dart';
import 'settings_page.dart';

/// F2-8 알림 설정 (Figma 216-5303). 답변 도착 알림을 켜고 끈다. 알림을 꺼도 답변은
/// 문의 목록에서 확인할 수 있다(FR-025).
class ParentSettingsPage extends ConsumerWidget {
  const ParentSettingsPage({super.key});

  static const offGuide = '알림을 꺼도 답변은 문의 목록에서 확인할 수 있어요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = parentSettingsViewModelProvider;
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('답변 도착 알림'),
              subtitle: const Text('선생님이 답변을 보내면 알려 드려요'),
              value: s.answerNotifyEnabled,
              onChanged: s.saving
                  ? null
                  : ref.read(provider.notifier).setAnswerNotify,
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const SystemNotice(offGuide, icon: Icons.info_outline),
            const DevicePermissionNotice(),
            MessageText(s.errorMessage),
          ],
        ),
      ),
    );
  }
}
