import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/field_error_text.dart';
import '../../../../core/widgets/form_layout.dart';
import 'password_reset_view_model.dart';

/// C-3 비밀번호 재설정 · 이메일 입력 (Figma 216-5029).
class ResetEmailPage extends ConsumerStatefulWidget {
  const ResetEmailPage({super.key});

  @override
  ConsumerState<ResetEmailPage> createState() => _ResetEmailPageState();
}

class _ResetEmailPageState extends ConsumerState<ResetEmailPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(passwordResetViewModelProvider.notifier)
        .requestReset(_email.text);
    if (ok && mounted) context.push('/password-reset/code');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetViewModelProvider);
    return FormPage(
      title: '비밀번호 재설정',
      children: [
        const Text('가입한 이메일을 입력하면 재설정 코드를 보내 드립니다.', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '이메일'),
          onChanged: ref.read(passwordResetViewModelProvider.notifier).emailChanged,
        ),
        FieldErrorText(state.fieldErrors['email']),
        MessageText(state.errorMessage),
        CooldownNotice(state.cooldown),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '재설정 코드 받기',
          isLoading: state.isSubmitting,
          onPressed: state.cooldown.isActive ? null : _submit,
        ),
      ],
    );
  }
}
