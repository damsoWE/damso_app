import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/form_layout.dart';
import 'teacher_inquiries_view_model.dart';
import 'teacher_inquiry_tile.dart';

/// F3-1 문의 목록 (Figma 216-5587). 긴급이 맨 위(서버 정렬), 끝까지 내리면 다음 페이지.
class TeacherInquiriesPage extends ConsumerWidget {
  const TeacherInquiriesPage({super.key});

  static const _loadMoreAhead = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(teacherInquiriesViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('문의')),
      body: RefreshIndicator(
        onRefresh: vm.refresh,
        child: AsyncView(
          value: ref.watch(teacherInquiriesViewModelProvider),
          onRetry: vm.refresh,
          isEmpty: (s) => s.items.isEmpty,
          empty: (_) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              Text(
                '담당 학급의 문의가 없습니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
          data: (s) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: s.items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전체 ${s.total} · 확인 전 긴급 ${s.unconfirmedUrgent.length}',
                        style: AppTextStyles.smallStrong,
                      ),
                      MessageText(s.refreshError),
                    ],
                  ),
                );
              }
              if (index == s.items.length + 1) return _Footer(state: s);
              final i = index - 1;
              if (i >= s.items.length - _loadMoreAhead && s.nextPage != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => vm.loadMore());
              }
              return TeacherInquiryTile(item: s.items[i]);
            },
          ),
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state});

  final TeacherInquiriesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = state.loadMoreError;
    if (error != null) {
      return Column(
        children: [
          MessageText(error),
          TextButton(
            onPressed: ref.read(teacherInquiriesViewModelProvider.notifier).loadMore,
            child: const Text('다시 시도'),
          ),
        ],
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}
