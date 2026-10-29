import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/models.dart';
import '../domain/notice_text.dart';
import 'format.dart';

/// 처리 단계 가로 진행 표시(spec FR-015, Figma F2-4 펼친 카드).
/// 지나온 단계는 채운 점과 시각, 아직 오지 않은 단계는 흐린 빈 점으로 그린다.
/// 서버는 "답변 완료" 단계를 기록하지 않으므로(api-v0.7) 그 칸은 [answeredAt]으로 채운다.
class StageTimeline extends StatelessWidget {
  const StageTimeline({
    super.key,
    required this.urgent,
    required this.events,
    this.answeredAt,
  });

  final bool urgent;
  final List<StageEvent> events;

  /// 마지막 답변 시각(`lastAnsweredAt`). null 이면 답변 없음.
  final DateTime? answeredAt;

  @override
  Widget build(BuildContext context) {
    final flow = InquiryStage.flowOf(urgent: urgent);
    final reached = {
      for (final e in events) e.stage: e.occurredAt,
      InquiryStage.answered: ?answeredAt,
    };
    // 도달한 단계 중 가장 뒤의 것이 현재 단계다(주황 링, Figma Steps).
    final current = flow.lastWhere(reached.containsKey, orElse: () => flow.first);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stage in flow)
          Expanded(
            child: _Step(
              label: NoticeText.stage(stage),
              at: reached[stage],
              current: stage == current,
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.at, required this.current});

  final String label;
  final DateTime? at;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final done = at != null;
    // 지나온 단계는 브랜드 색 채움, 현재 단계는 주황 링, 아직 오지 않은 단계는 회색 링.
    final color = current
        ? AppColors.brandAccent
        : (done ? AppColors.brandPrimary : AppColors.borderDefault);
    return Column(
      children: [
        Icon(done && !current ? Icons.circle : Icons.circle_outlined, size: 14, color: color),
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
