import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/answer_text.dart';
import '../domain/models.dart';

/// 점검 결과 제안 카드 하나(Figma F4-2c 216-5411 · F4-2c-1 216-5439).
/// 제목은 순번만 쓴다 — 서버가 분류 제목을 주지 않는다(Clarifications Q2).
/// "바꾸기"·"되돌리기"는 교사가 누를 때만 본문을 바꾼다(원칙 V).
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.index,
    required this.highlight,
    required this.applied,
    required this.canApply,
    required this.onApply,
    required this.onUndo,
  });

  final int index;
  final Highlight highlight;
  final bool applied;
  final bool canApply;
  final VoidCallback onApply;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final first = index == 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: applied
            ? AppColors.statusSuccessSoft
            : first
            ? AppColors.statusInfoSoft
            : AppColors.bgSurface,
        border: first || applied ? null : Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AnswerText.suggestionTitle(index + 1, applied: applied),
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            highlight.reason,
            style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.ms),
          Container(
            padding: const EdgeInsets.all(AppSpacing.ms),
            decoration: BoxDecoration(
              color: applied ? AppColors.bgSurface : AppColors.statusSuccessSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        applied ? AnswerText.appliedLabel : AnswerText.rewrittenLabel,
                        style: AppTextStyles.label,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: applied ? onUndo : (canApply ? onApply : null),
                      child: Text(applied ? AnswerText.undoButton : AnswerText.applyButton),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('“${highlight.suggestion}”', style: AppTextStyles.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
