import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/app_theme.dart';

/// C-6 담소 이용 안내 (Figma 216-5082). 고정 문구만 쓴다(원칙 V).
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  static const _guides = [
    ('대화는 기록으로 남아요', '보낸 문의와 답변은 수정하거나 지울 수 없어요.'),
    ('연락처는 주고받지 않아요', '전화번호·주소 없이 담소 안에서만 이야기해요.'),
    ('급한 안전 문제는 바로 전달돼요', '학생 안전과 관련된 내용은 선생님께 즉시 알려요.'),
  ];

  void _confirm(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionControllerProvider);
    if (session is SignedIn && session.justSignedUp) {
      ref.read(sessionControllerProvider.notifier).acknowledgeWelcome();
      context.go(session.role.homePath);
    } else {
      context.pop(); // 마이페이지에서 열람한 경우
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('담소 이용 안내')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final (title, body) in _guides) ...[
              Text(title, style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
            ],
            FilledButton(
              onPressed: () => _confirm(context, ref),
              child: const Text('확인했어요'),
            ),
          ],
        ),
      ),
    );
  }
}
