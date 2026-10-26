import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import 'teacher_inquiries_view_model.dart';
import 'teacher_inquiry_tile.dart';

/// 교사 홈(F3-4 Figma 216-5567)의 문의 영역: 확인 전 긴급 카드와 최근 문의(FR-021).
class TeacherHomeInquirySection extends ConsumerWidget {
  const TeacherHomeInquirySection({super.key});

  static const _recent = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(teacherInquiriesViewModelProvider.notifier);
    return AsyncView(
      value: ref.watch(teacherInquiriesViewModelProvider),
      onRetry: vm.refresh,
      data: (s) {
        final urgent = s.unconfirmedUrgent.toList();
        final recent = s.items.where((i) => !i.isUnconfirmedUrgent).take(_recent);
        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (urgent.isNotEmpty) ...[
                _UrgentCard(
                  count: urgent.length,
                  // 가장 최근 확인 전 긴급 문의를 연다(서버가 긴급을 최신순으로 먼저 준다).
                  onTap: () => context.push(TeacherInquiryTile.pathOf(urgent.first)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const Text('최근 문의', style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.sm),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('담당 학급의 문의가 없습니다.', style: AppTextStyles.body),
                )
              else
                for (final item in recent) TeacherInquiryTile(item: item),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.go('/teacher/inquiries'),
                child: const Text('문의 목록 보기'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.statusUrgentSoft,
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        title: Text('긴급 문의 $count건', style: AppTextStyles.subtitle),
        subtitle: const Text('학생 안전 관련 문의가 바로 전달됐어요.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
