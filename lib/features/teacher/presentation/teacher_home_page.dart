import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// F3-4 교사 홈 (Figma 216-5567). 이 작업에서는 진입 화면만 둔다(FR-031, 문의는 F2).
class TeacherHomePage extends StatelessWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교사 홈'),
        actions: [
          IconButton(
            tooltip: '마이페이지',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/teacher/me'),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '선생님, 안녕하세요.\n학부모 연결 현황과 공개 프로필은 마이페이지에서 관리할 수 있습니다.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ),
      ),
    );
  }
}
