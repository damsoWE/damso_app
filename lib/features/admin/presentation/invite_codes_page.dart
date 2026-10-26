import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../domain/models.dart';
import 'format.dart';
import 'invite_codes_view_model.dart';

/// 학급별 초대 코드 발행 현황(FR-036). 코드 원문은 없다.
class InviteCodesPage extends ConsumerWidget {
  const InviteCodesPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = inviteCodesViewModelProvider(classroomId);
    return Scaffold(
      appBar: AppBar(title: const Text('발행 현황')),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: ref.read(provider.notifier).refresh,
        isEmpty: (list) => list.isEmpty,
        empty: (_) => const Center(child: Text('발행한 코드가 없습니다.')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = list[i];
            final kind = c.kind == InviteCodeKind.teacher
                ? '교사 코드'
                : '학부모 코드 · ${c.studentName ?? ''}';
            final used = c.usedAt;
            return ListTile(
              title: Text(kind),
              subtitle: Text(
                [
                  '발행 ${formatDateTime(c.issuedAt)}',
                  '만료 ${formatDateTime(c.expiresAt)}',
                  if (used != null) '사용 ${formatDateTime(used)}',
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: _StateChip(c.status),
            );
          },
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.state);

  final InviteCodeState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      InviteCodeState.unused => (AppColors.statusInfoSoft, AppColors.statusInfo),
      InviteCodeState.used => (AppColors.statusSuccessSoft, AppColors.statusSuccess),
      InviteCodeState.expired ||
      InviteCodeState.revoked => (AppColors.statusSystemSoft, AppColors.statusSystem),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(inviteStateLabel(state), style: AppTextStyles.label.copyWith(color: fg)),
    );
  }
}
