import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 입력란 아래 안내 한 줄. [message] 가 null 이면 아무것도 그리지 않는다.
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.message, {super.key});

  /// 서버 fieldErrors 가 앱 검증 결과보다 우선한다(research R9).
  const FieldErrorText.pick({super.key, String? server, String? client})
    : message = server ?? client;

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: AppTextStyles.micro.copyWith(color: AppColors.statusUrgentText),
      ),
    );
  }
}
