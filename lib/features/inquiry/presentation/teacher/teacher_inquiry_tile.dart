import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';

/// 교사 문의 목록 항목(F3-1 Figma 216-5587, F3-4). 학생 이름으로 구분하고 학부모 정보는 없다(FR-023).
class TeacherInquiryTile extends StatelessWidget {
  const TeacherInquiryTile({super.key, required this.item});

  final TeacherInquirySummary item;

  /// 긴급은 원문 상세(F3-5), 일반은 정리 상태별 상세(F3-2·F3-3·F3-3a, specs/003 FR-001).
  static String pathOf(TeacherInquirySummary item) => item.urgent
      ? '/teacher/inquiries/${item.inquiryId}/urgent'
      : '/teacher/inquiries/${item.inquiryId}/general';

  @override
  Widget build(BuildContext context) {
    return Card(
      color: item.urgent ? AppColors.statusUrgentSoft : AppColors.bgSurface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        title: Text(item.title, style: AppTextStyles.subtitle),
        subtitle: Text(
          '${item.studentName} · ${formatDateTime(item.submittedAt)} · '
          '${NoticeText.stage(item.displayStage)}',
        ),
        trailing: item.urgent ? const _UrgentBadge() : null,
        onTap: () => context.push(pathOf(item)),
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.statusUrgent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '긴급',
        style: AppTextStyles.label.copyWith(color: AppColors.textInverse),
      ),
    );
  }
}
