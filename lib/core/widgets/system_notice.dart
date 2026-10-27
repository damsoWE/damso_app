import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 시스템 발신 안내(원칙 V). 교사 메시지와 구분되도록 회색 바탕 + 방패 아이콘으로 그린다.
/// 문구는 호출하는 쪽의 고정 상수만 넘긴다.
class SystemNotice extends StatelessWidget {
  const SystemNotice(this.text, {super.key, this.icon = Icons.shield_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusSystemSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.statusSystem),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.small.copyWith(color: AppColors.statusSystem),
            ),
          ),
        ],
      ),
    );
  }
}
