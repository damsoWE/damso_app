import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import 'login_view_model.dart';

/// 로그인 화면 자리표시. 실제 UI·상태는 F1 spec 에서 정의한다.
/// 로직은 LoginViewModel 에 있고, 화면은 입력을 전달하고 상태를 그리기만 한다.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(loginViewModelProvider.notifier)
        .login(email: _email.text.trim(), password: _password.text);
    if (ok && mounted) context.go('/inquiries');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('담소')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  // 서버 message 만 보여 준다. 예외 객체는 노출하지 않는다.
                  state.error is AppException
                      ? (state.error as AppException).message
                      : '로그인하지 못했습니다.',
                ),
              ),
            FilledButton(
              onPressed: state.isLoading ? null : _submit,
              child: state.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
