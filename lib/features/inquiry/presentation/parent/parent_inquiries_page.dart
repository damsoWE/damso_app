import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import 'inquiry_card.dart';
import 'parent_inquiries_view_model.dart';

/// F2-4 나의 문의 목록 (Figma 216-5272). 카드를 누르면 스레드(F4-1, specs/007).
class ParentInquiriesPage extends ConsumerWidget {
  const ParentInquiriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(parentInquiriesViewModelProvider.notifier);
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
                InquiryCard(key: ValueKey(s.inquiryId), summary: s),
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
