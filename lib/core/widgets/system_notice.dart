import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 시스템 발신 안내(원칙 V). 교사 메시지와 구분되도록 회색 바탕 + 방패 아이콘으로 그린다.
/// 문구는 호출하는 쪽의 고정 상수만 넘긴다.
class SystemNotice extends StatelessWidget {
  const SystemNotice(
    this.text, {
    super.key,
    this.icon = Icons.shield_outlined,
    this.tone = NoticeTone.system,
  });

  final String text;
  final IconData icon;

  /// 안내 색(Figma `공통 · 컴포넌트` Notice: 정보·경고·긴급·성공·시스템).
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.ms),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone.icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.small.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// [SystemNotice] 의 색 변형. 기본은 회색 시스템 안내다.
enum NoticeTone {
  system(AppColors.statusSystemSoft, AppColors.statusSystem),
  info(AppColors.statusInfoSoft, AppColors.statusInfo),
  warning(AppColors.statusWarningSoft, AppColors.textPrimary, AppColors.statusWarning),
  urgent(AppColors.statusUrgentSoft, AppColors.statusUrgentText, AppColors.statusUrgent),
  success(AppColors.statusSuccessSoft, AppColors.statusSuccess);

  const NoticeTone(this.background, this.foreground, [Color? icon]) : icon = icon ?? foreground;

  final Color background;

  /// 글자 색.
  final Color foreground;

  /// 아이콘 색. 경고·긴급은 글자보다 진한 상태 색을 쓴다.
  final Color icon;
}
