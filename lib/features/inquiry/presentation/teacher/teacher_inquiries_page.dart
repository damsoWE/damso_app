import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/form_layout.dart';
import 'teacher_inquiries_view_model.dart';
import 'teacher_inquiry_tile.dart';

/// F3-1 문의 목록 (Figma 216-5587 답변 대기 · 352-1856 답변 완료). 위의 두 칸으로 나눠 보고
/// (specs/004 FR-028), 긴급이 맨 위(서버 정렬), 끝까지 내리면 다음 페이지.
class TeacherInquiriesPage extends ConsumerWidget {
  const TeacherInquiriesPage({super.key});

  static const _loadMoreAhead = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(teacherInquiriesViewModelProvider.notifier);
    final tab = ref.watch(inquiryTabProvider);
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
          data: (s) {
            final items = s.itemsOf(tab);
            final urgent = items.where((i) => i.urgent).length;
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SegmentTabs(
                          selected: tab,
                          waiting: s.itemsOf(InquiryTab.waiting).length,
                          answered: s.itemsOf(InquiryTab.answered).length,
                          onSelect: ref.read(inquiryTabProvider.notifier).select,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // 두 칸 모두 Medium 14(답변 대기와 같게).
                        Text(
                          '전체 ${items.length} · 긴급 $urgent · 일반 ${items.length - urgent}',
                          style: AppTextStyles.smallStrong,
                        ),
                        MessageText(s.refreshError),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                            child: Text(
                              tab == InquiryTab.waiting
                                  ? '답변을 기다리는 문의가 없습니다.'
                                  : '답변한 문의가 없습니다.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body,
                            ),
                          ),
                      ],
                    ),
                  );
                }
                if (index == items.length + 1) return _Footer(state: s);
                final i = index - 1;
                if (i >= items.length - _loadMoreAhead) _loadMoreLater(s, vm);
                return TeacherInquiryTile(item: items[i]);
              },
            );
          },
        ),
      ),
    );
  }

  static void _loadMoreLater(TeacherInquiriesState s, TeacherInquiriesViewModel vm) {
    if (s.nextPage != null && !s.isLoadingMore && s.loadMoreError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => vm.loadMore());
    }
  }
}

/// [답변 대기 N | 답변 완료 N] 두 칸(Figma `SegmentTabs` 351-1866).
class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.selected,
    required this.waiting,
    required this.answered,
    required this.onSelect,
  });

  final InquiryTab selected;
  final int waiting;
  final int answered;
  final ValueChanged<InquiryTab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(InquiryTab tab, String label) {
      final on = tab == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? AppColors.bgSurface : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: on ? const BorderSide(color: AppColors.borderDefault) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => onSelect(tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.smallStrong.copyWith(
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          item(InquiryTab.waiting, '답변 대기 $waiting'),
          const SizedBox(width: AppSpacing.xs),
          item(InquiryTab.answered, '답변 완료 $answered'),
        ],
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
            onPressed: () => ref
                .read(teacherInquiriesViewModelProvider.notifier)
                .loadMore(retry: true),
            child: const Text('다시 시도'),
          ),
        ],
      );
    }
    // 고른 칸의 문의가 적어 끝이 바로 보여도 다음 페이지를 부른다(칸은 불러온 문의 안에서 나눔).
    TeacherInquiriesPage._loadMoreLater(
      state,
      ref.read(teacherInquiriesViewModelProvider.notifier),
    );
    return const SizedBox(height: AppSpacing.lg);
  }
}
