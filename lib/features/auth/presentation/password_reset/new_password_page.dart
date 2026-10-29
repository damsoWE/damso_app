import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/field_error_text.dart';
import '../../../../core/widgets/form_layout.dart';
import 'password_reset_view_model.dart';

/// C-4 새 비밀번호 설정 (Figma 216-5115).
class ResetNewPasswordPage extends ConsumerStatefulWidget {
  const ResetNewPasswordPage({super.key});

  @override
  ConsumerState<ResetNewPasswordPage> createState() =>
      _ResetNewPasswordPageState();
}

class _ResetNewPasswordPageState extends ConsumerState<ResetNewPasswordPage> {
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = ref.read(passwordResetViewModelProvider.notifier);
    final ok = await vm.confirm(_password.text);
    if (!mounted) return;
    if (ok) {
      context.go('/password-reset/done');
    } else if (ref.read(passwordResetViewModelProvider).step ==
        ResetStep.expiredOrLocked) {
      context.pop(); // C-3c 로
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetViewModelProvider);
    return FormPage(
      title: '새 비밀번호',
      bottom: [
        SubmitButton(
          label: '비밀번호 변경',
          isLoading: state.isSubmitting,
          onPressed: validateNewPassword(_password.text) == null ? _submit : null,
        ),
      ],
      children: [
        const Text('새로 사용할 비밀번호를 입력해 주세요.', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _password,
          autofillHints: const [AutofillHints.newPassword],
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: '새 비밀번호',
            helperText: '영문과 숫자를 포함해 8~64자',
          ),
        ),
        FieldErrorText.pick(
          server: state.fieldErrors['newPassword'],
          client: _password.text.isEmpty ? null : validateNewPassword(_password.text),
        ),
        MessageText(state.errorMessage),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
