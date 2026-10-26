import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/form_layout.dart';
import 'password_reset_view_model.dart';

/// C-3b 재설정 코드 입력 (Figma 216-5039) · C-3c 코드 만료·횟수 초과 (216-5143).
class ResetCodePage extends ConsumerStatefulWidget {
  const ResetCodePage({super.key});

  @override
  ConsumerState<ResetCodePage> createState() => _ResetCodePageState();
}

class _ResetCodePageState extends ConsumerState<ResetCodePage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref
        .read(passwordResetViewModelProvider.notifier)
        .verifyCode(_code.text);
    if (ok && mounted) context.push('/password-reset/new');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetViewModelProvider);
    final vm = ref.read(passwordResetViewModelProvider.notifier);

    if (state.step == ResetStep.expiredOrLocked) {
      return FormPage(
        title: '재설정 코드',
        children: [
          const Text('코드가 만료되었거나 입력 횟수를 넘었습니다.', style: AppTextStyles.subtitle),
          MessageText(state.errorMessage),
          const SizedBox(height: AppSpacing.md),
          SubmitButton(
            label: '코드 다시 받기',
            isLoading: state.isSubmitting,
            onPressed: () {
              _code.clear();
              vm.resendCode();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: () => context.go('/'), child: const Text('로그인으로')),
        ],
      );
    }

    return FormPage(
      title: '재설정 코드',
      children: [
        Text(
          '${state.email}(으)로 보낸 6자리 코드를 입력해 주세요.',
          style: AppTextStyles.body,
        ),
        MessageText(state.notice, isError: false),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: '재설정 코드'),
        ),
        MessageText(state.errorMessage),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '코드 확인',
          isLoading: state.isSubmitting,
          onPressed: validateSixDigitCode(_code.text) == null ? _verify : null,
        ),
      ],
    );
  }
}
