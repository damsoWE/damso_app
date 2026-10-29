import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/form_layout.dart';
import 'teacher_inquiries_view_model.dart';
import 'teacher_inquiry_tile.dart';

/// F3-1 문의 목록 (Figma 216-5587 답변 대기 · 352-1856 답변 완료). 위의 두 칸은 서버가 거른
/// 목록을 따로 불러오고(api-v0.11 `answerStatus`, specs/004 FR-028), 칸 옆 개수는 서버 전체 수다.
/// 긴급이 맨 위(서버 정렬), 끝까지 내리면 그 칸의 다음 페이지.
class TeacherInquiriesPage extends ConsumerWidget {
  const TeacherInquiriesPage({super.key});

  static const _loadMoreAhead = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(inquiryTabProvider);
    final provider = teacherInquiryTabViewModelProvider(tab);
    final vm = ref.read(provider.notifier);
    // 칸 옆 개수를 위해 두 칸을 함께 불러 둔다.
    final waitingTotal =
        ref.watch(teacherInquiryTabViewModelProvider(InquiryTab.waiting)).value?.total;
    final answeredTotal =
        ref.watch(teacherInquiryTabViewModelProvider(InquiryTab.answered)).value?.total;
    Future<void> refreshBoth() => Future.wait([
      for (final t in InquiryTab.values)
        ref.read(teacherInquiryTabViewModelProvider(t).notifier).refresh(),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('문의')),
      body: RefreshIndicator(
        onRefresh: refreshBoth,
        child: AsyncView(
          value: ref.watch(provider),
          onRetry: vm.refresh,
          data: (s) {
            final items = s.items;
            // 긴급이 먼저 오므로 불러온 항목의 긴급 수가 칸 전체의 긴급 수다.
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
                          waiting: waitingTotal,
                          answered: answeredTotal,
                          onSelect: ref.read(inquiryTabProvider.notifier).select,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // 두 칸 모두 Medium 14(답변 대기와 같게).
                        Text(
                          '전체 ${s.total} · 긴급 $urgent · 일반 ${s.total - urgent}',
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
                if (index == items.length + 1) return _Footer(tab: tab, state: s);
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

/// [답변 대기 N | 답변 완료 N] 두 칸(Figma `SegmentTabs` 351-1866). 아직 못 받은 칸은 이름만.
class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.selected,
    required this.waiting,
    required this.answered,
    required this.onSelect,
  });

  final InquiryTab selected;
  final int? waiting;
  final int? answered;
  final ValueChanged<InquiryTab> onSelect;

  static String _label(String name, int? count) => count == null ? name : '$name $count';

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
          item(InquiryTab.waiting, _label('답변 대기', waiting)),
          const SizedBox(width: AppSpacing.xs),
          item(InquiryTab.answered, _label('답변 완료', answered)),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.tab, required this.state});

  final InquiryTab tab;
  final TeacherInquiriesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(teacherInquiryTabViewModelProvider(tab).notifier);
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
            onPressed: () => vm.loadMore(retry: true),
            child: const Text('다시 시도'),
          ),
        ],
      );
    }
    // 목록이 짧아 끝이 바로 보여도 다음 페이지가 있으면 부른다.
    TeacherInquiriesPage._loadMoreLater(state, vm);
    return const SizedBox(height: AppSpacing.lg);
  }
}
