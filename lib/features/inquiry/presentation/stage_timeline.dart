import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/models.dart';
import '../domain/notice_text.dart';
import 'format.dart';

/// 처리 단계 가로 진행 표시(spec FR-015, Figma F2-4 펼친 카드).
/// 지나온 단계는 채운 점과 시각, 아직 오지 않은 단계는 흐린 빈 점으로 그린다.
class StageTimeline extends StatelessWidget {
  const StageTimeline({super.key, required this.urgent, required this.events});

  final bool urgent;
  final List<StageEvent> events;

  @override
  Widget build(BuildContext context) {
    final flow = InquiryStage.flowOf(urgent: urgent);
    final reached = {for (final e in events) e.stage: e.occurredAt};
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stage in flow)
          Expanded(
            child: _Step(
              label: NoticeText.stage(stage),
              at: reached[stage],
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.at});

  final String label;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final done = at != null;
    final color = done ? AppColors.brandPrimary : AppColors.borderDefault;
    return Column(
      children: [
        Icon(done ? Icons.circle : Icons.circle_outlined, size: 14, color: color),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.micro.copyWith(
            color: done ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
        if (done)
          Text(
            formatDateTime(at!),
            textAlign: TextAlign.center,
            style: AppTextStyles.micro.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}
