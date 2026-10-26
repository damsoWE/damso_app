import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import 'inquiry_card.dart';
import 'parent_inquiries_view_model.dart';

/// F2-4 나의 문의 목록 (Figma 216-5272). 카드를 펼치면 처리 단계(FR-015).
/// 상세 스레드(F4-1)는 F4 범위라 이번에는 펼치기까지만 한다.
class ParentInquiriesPage extends ConsumerWidget {
  const ParentInquiriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(parentInquiriesViewModelProvider.notifier);
    // 펼친 카드 상세가 목록 화면이 살아 있는 동안 남도록 구독해 둔다.
    ref.watch(parentInquiryDetailsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('문의')),
      body: RefreshIndicator(
        onRefresh: vm.refresh,
        child: AsyncView(
          value: ref.watch(parentInquiriesViewModelProvider),
          onRetry: vm.refresh,
          isEmpty: (list) => list.isEmpty,
          empty: (_) => const _Empty(),
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final s in list) ...[
                InquiryCard(
                  key: ValueKey(s.inquiryId),
                  summary: s,
                  onUrgentTap: () =>
                      context.push('/parent/inquiries/${s.inquiryId}/urgent'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '새 문의는 홈에서 자녀를 고른 뒤 작성할 수 있어요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Text(
          '보낸 문의가 없습니다.',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => context.go('/parent'),
          child: const Text('문의 작성'),
        ),
      ],
    );
  }
}
