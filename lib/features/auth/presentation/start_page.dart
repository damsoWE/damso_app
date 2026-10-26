import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// C-0 시작 (Figma 216-5016).
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                '담소',
                textAlign: TextAlign.center,
                style: AppTextStyles.display.copyWith(color: AppColors.brandPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '선생님과 보호자를 잇는 차분한 대화',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push('/login'),
                child: const Text('로그인'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.push('/signup'),
                child: const Text('초대코드로 가입하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
