import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/form_layout.dart';

/// C-5 비밀번호 변경 완료 (Figma 216-5128).
class ResetDonePage extends StatelessWidget {
  const ResetDonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: '비밀번호 변경 완료',
      bottom: [
        FilledButton(onPressed: () => context.go('/'), child: const Text('로그인하기')),
      ],
      children: [
        const Text('비밀번호를 바꿨습니다.', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '모든 기기에서 로그아웃되었습니다. 새 비밀번호로 다시 로그인해 주세요.',
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}
