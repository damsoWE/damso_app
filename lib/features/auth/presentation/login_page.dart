import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository_impl.dart';

/// 로그인 화면 자리표시. 실제 UI·상태는 F1 spec 에서 정의한다.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('담소')),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            await ref
                .read(authRepositoryProvider)
                .login(email: 'demo@example.com', password: 'demo');
            if (context.mounted) context.go('/inquiries');
          },
          child: const Text('로그인'),
        ),
      ),
    );
  }
}
