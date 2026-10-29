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

  /// 한 번이라도 답변한 문의는 스레드(F4-3, specs/004 FR-014 — 서버 `hasAnswer`로 판단).
  /// 그 밖에 긴급은 원문 상세(F3-5), 일반은 정리 상태별 상세(F3-2·F3-3·F3-3a, specs/003 FR-001).
  static String pathOf(TeacherInquirySummary item) => item.hasAnswer
      ? '/teacher/inquiries/${item.inquiryId}/thread'
      : item.urgent
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
        subtitle: Text('${item.studentName} · ${_status(item)}'),
        trailing: item.urgent
            ? const _Badge('긴급', background: AppColors.statusUrgent, foreground: AppColors.textInverse)
            : item.hasNewFollowUp
            ? const _Badge('재문의', background: AppColors.statusInfoSoft, foreground: AppColors.statusInfo)
            : null,
        onTap: () => context.push(pathOf(item)),
      ),
    );
  }

  /// 부제 뒷부분(specs/004 FR-030, Figma F3-1·F3-1b). 학부모 정보는 넣지 않는다.
  static String _status(TeacherInquirySummary item) {
    final answeredAt = item.lastAnsweredAt;
    if (item.hasNewFollowUp) {
      return '재문의 받음 · ${formatDateTime(item.lastFollowUpAt ?? item.submittedAt)}';
    }
    if (!item.needsAnswer && answeredAt != null) {
      return '답변 완료 · ${formatDateTime(answeredAt)} 답변';
    }
    return '${formatDateTime(item.submittedAt)} · ${NoticeText.stage(item.displayStage)}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.background, required this.foreground});

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: AppTextStyles.label.copyWith(color: foreground)),
    );
  }
}
