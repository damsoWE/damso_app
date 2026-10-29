import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';

/// 학부모 문의 카드(F2-4 Figma 216-5272, 홈 문의 영역). 서버 제목이 없어
/// 자녀 이름·긴급 표시·접수 시각·현재 단계로 구분한다(FR-014, FR-016).
/// 카드를 누르면 스레드(F4-1)로 간다. 답변이 없는 긴급 문의만 기존 긴급 안내로 간다(specs/007 R6).
class InquiryCard extends StatelessWidget {
  const InquiryCard({super.key, required this.summary});

  final ParentInquirySummary summary;

  /// 카드를 눌렀을 때 갈 경로.
  static String routeOf(ParentInquirySummary s) => s.urgent && !s.hasAnswer
      ? '/parent/inquiries/${s.inquiryId}/urgent'
      : '/parent/inquiries/${s.inquiryId}/thread';

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final title = s.urgent ? NoticeText.urgentLabel : '${s.studentName} 학생 문의';
    return Card(
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: s.urgent ? AppColors.statusUrgent : AppColors.borderDefault,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        title: Text(title, style: AppTextStyles.subtitle),
        subtitle: Text(
          '${s.urgent ? '${s.studentName} · ' : ''}'
          '${formatDateTime(s.submittedAt)} · ${NoticeText.stage(s.displayStage)}',
        ),
        trailing: s.urgent ? const _Badge('긴급') : null,
        onTap: () => context.push(routeOf(s)),
      ),
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
