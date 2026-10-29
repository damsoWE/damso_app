import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cooldown.dart';
import '../../../core/widgets/field_error_text.dart';
import '../../../core/widgets/form_layout.dart';
import 'login_view_model.dart';

/// C-1 로그인 (Figma 224-1169) · C-1a 로그인 대기 (225-1512).
/// 대기 안내는 서버가 알려 준 남은 시간만 쓴다. "5회 실패, 10분" 같은 고정 문구는 쓰지 않는다.
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

  void _submit() {
    ref
        .read(loginViewModelProvider.notifier)
        .login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);

    return FormPage(
      title: '로그인',
      children: [
        TextField(
          controller: _email,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        FieldErrorText(state.fieldErrors['email']),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _password,
          autofillHints: const [AutofillHints.password],
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: '비밀번호'),
          onSubmitted: (_) => _submit(),
        ),
        FieldErrorText(state.fieldErrors['password']),
        MessageText(state.errorMessage),
        CooldownNotice(state.cooldown),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '로그인',
          isLoading: state.isSubmitting,
          onPressed: state.cooldown.isActive ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push('/password-reset'),
              child: const Text('비밀번호 재설정'),
            ),
            TextButton(
              onPressed: () => context.push('/signup'),
              child: const Text('가입하기'),
            ),
          ],
        ),
      ],
    );
  }
}
