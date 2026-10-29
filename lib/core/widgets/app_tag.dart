import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 상태 태그(Figma `공통 · 컴포넌트` Tag). 알약 모양, 글자는 `담소/Label`.
class AppTag extends StatelessWidget {
  const AppTag(this.text, {super.key, this.tone = TagTone.neutral});

  final String text;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tone.background,
        border: tone.border == null ? null : Border.all(color: tone.border!),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: AppTextStyles.label.copyWith(color: tone.foreground)),
    );
  }
}

/// [AppTag] 의 색 변형(Figma Tag `tone`).
enum TagTone {
  neutral(AppColors.bgSubtle, AppColors.textSecondary),
  urgent(AppColors.statusUrgent, AppColors.textInverse),
  success(AppColors.statusSuccessSoft, AppColors.statusSuccess),
  warning(AppColors.statusWarningSoft, AppColors.statusWarning),
  info(AppColors.statusInfoSoft, AppColors.statusInfo),
  system(AppColors.statusSystemSoft, AppColors.statusSystem),

  /// Figma `Dark`: 흰 바탕 + 브랜드 색 테두리·글자.
  brand(AppColors.bgSurface, AppColors.brandPrimary, AppColors.brandPrimary),
  outline(AppColors.bgSurface, AppColors.textSecondary, AppColors.borderStrong);

  const TagTone(this.background, this.foreground, [this.border]);

  final Color background;
  final Color foreground;
  final Color? border;
}
