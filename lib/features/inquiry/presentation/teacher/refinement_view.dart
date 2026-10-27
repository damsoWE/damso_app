import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';

/// 번역본 카드(F3-2 Figma 216-5607): 사실관계 · 요청사항 · 정서강도.
/// Figma 의 "빠른 회신 권장" 자리에 정서강도·감정 라벨을 보인다(specs/003 research R7).
/// 라우터·ViewModel 에 기대지 않아 F4 답변 작성 화면이 다시 쓸 수 있다.
/// 글은 일반 Text 로만 보인다(FR-007).
class RefinementView extends StatelessWidget {
  const RefinementView({super.key, required this.refinement});

  final InquiryRefinement refinement;

  @override
  Widget build(BuildContext context) {
    final r = refinement;
    final hasEmotion = r.emotionLevel != null || r.emotionLabels.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(title: NoticeText.factsLabel, body: r.facts),
        const SizedBox(height: AppSpacing.ms),
        _Section(
          title: NoticeText.requestsLabel,
          body: r.requests.isEmpty ? NoticeText.noRequests : r.requests,
        ),
        if (hasEmotion) ...[
          const SizedBox(height: AppSpacing.ms),
          _EmotionCard(level: r.emotionLevel, labels: r.emotionLabels),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subtitle),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.small.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 정서강도를 모르면 단계 줄만, 라벨이 없으면 칩 줄만 숨긴다(FR-005a, research R8).
class _EmotionCard extends StatelessWidget {
  const _EmotionCard({required this.level, required this.labels});

  final EmotionLevel? level;
  final List<EmotionLabel> labels;

  @override
  Widget build(BuildContext context) {
    final level = this.level;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusInfoSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(NoticeText.emotionTitle, style: AppTextStyles.subtitle),
          if (level != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: _dotColor(level)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  NoticeText.emotionLevel(level),
                  style: AppTextStyles.bodyStrong.copyWith(color: _textColor(level)),
                ),
              ],
            ),
          ],
          if (labels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [for (final l in labels) _Chip(NoticeText.emotionLabel(l))],
            ),
          ],
        ],
      ),
    );
  }

  static Color _dotColor(EmotionLevel level) => switch (level) {
    EmotionLevel.low => AppColors.emotionLow,
    EmotionLevel.medium => AppColors.emotionMid,
    EmotionLevel.high => AppColors.emotionHigh,
  };

  static Color _textColor(EmotionLevel level) => switch (level) {
    EmotionLevel.low => AppColors.emotionLowText,
    EmotionLevel.medium => AppColors.emotionMidText,
    EmotionLevel.high => AppColors.emotionHighText,
  };
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.ms, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: AppTextStyles.smallStrong),
    );
  }
}
