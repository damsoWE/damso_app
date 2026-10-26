import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// C-7 이용약관 · 개인정보 처리방침 (Figma 225-1591). 임시 문안, 일반 텍스트로만 표시한다.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const _sections = [
    ('이용약관 (임시 문안)', '담소는 학교와 보호자 사이의 소통을 돕는 서비스입니다. 정식 약관은 서비스 출시 전에 안내합니다.'),
    (
      '개인정보 처리방침 (임시 문안)',
      '담소는 가입과 로그인에 필요한 이름·이메일만 수집합니다. 전화번호·주소 등 연락처는 수집하지 않습니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용약관 · 개인정보 처리방침')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final (title, body) in _sections) ...[
              Text(title, style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
            ],
            FilledButton(onPressed: () => context.pop(), child: const Text('확인')),
          ],
        ),
      ),
    );
  }
}
