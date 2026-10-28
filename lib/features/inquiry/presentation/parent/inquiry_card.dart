import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import '../stage_timeline.dart';
import 'parent_inquiries_view_model.dart';

/// 학부모 문의 카드(F2-4 Figma 216-5272, 홈 문의 영역). 서버 제목이 없어
/// 자녀 이름·긴급 표시·접수 시각·현재 단계로 구분한다(FR-014, FR-016).
/// [expandable]이면 펼쳐서 처리 단계를 본다(상세는 펼칠 때 한 번만 불러온다).
class InquiryCard extends ConsumerStatefulWidget {
  const InquiryCard({
    super.key,
    required this.summary,
    this.expandable = true,
    this.onUrgentTap,
    this.onTap,
  });

  final ParentInquirySummary summary;
  final bool expandable;

  /// 긴급 카드를 누르면 긴급 안내 다시 보기(FR-018).
  final VoidCallback? onUrgentTap;

  /// 펼칠 수 없는 카드(홈)를 누를 때.
  final VoidCallback? onTap;

  @override
  ConsumerState<InquiryCard> createState() => _InquiryCardState();
}

class _InquiryCardState extends ConsumerState<InquiryCard> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      ref
          .read(parentInquiryDetailsProvider.notifier)
          .load(widget.summary.inquiryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final title = s.urgent ? NoticeText.urgentLabel : '${s.studentName} 학생 문의';
    return Card(
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: s.urgent ? AppColors.statusUrgent : AppColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            title: Text(title, style: AppTextStyles.subtitle),
            subtitle: Text(
              '${s.urgent ? '${s.studentName} · ' : ''}'
              '${formatDateTime(s.submittedAt)} · ${NoticeText.stage(s.displayStage)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.urgent) const _Badge('긴급'),
                if (widget.expandable)
                  IconButton(
                    tooltip: _expanded ? '접기' : '펼치기',
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: _toggle,
                  ),
              ],
            ),
            onTap: s.urgent
                ? widget.onUrgentTap
                : (widget.expandable ? _toggle : widget.onTap),
          ),
          if (_expanded) _Timeline(summary: s),
        ],
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.summary});

  final ParentInquirySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      parentInquiryDetailsProvider.select((m) => m[summary.inquiryId]),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: switch (detail) {
        AsyncData(:final value) => StageTimeline(
          urgent: summary.urgent,
          events: value.timeline,
          answeredAt: value.summary.lastAnsweredAt,
        ),
        AsyncError(:final error) => Text(
          userMessageOf(error),
          style: AppTextStyles.small.copyWith(color: AppColors.statusUrgentText),
        ),
        _ => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.statusUrgent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(color: AppColors.textInverse),
      ),
    );
  }
}
