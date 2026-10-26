import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/form_layout.dart';
import 'signup_view_model.dart';

/// C-2 이메일 인증 (Figma 224-1185). 성공 후 이동은 라우터 redirect(/welcome)에 맡긴다.
class SignupVerifyPage extends ConsumerStatefulWidget {
  const SignupVerifyPage({super.key});

  @override
  ConsumerState<SignupVerifyPage> createState() => _SignupVerifyPageState();
}

class _SignupVerifyPageState extends ConsumerState<SignupVerifyPage> {
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
    final outcome = await ref
        .read(signupViewModelProvider.notifier)
        .verify(_code.text);
    // 스택을 교체(go)하면 시작 화면이 사라져 시스템 뒤로 가기에 앱이 닫힌다.
    // 계정 정보 화면에 결과를 넘겨 F1-1 까지 pop 으로 돌아간다.
    if (outcome == SignupOutcome.backToCode && mounted) {
      context.pop(SignupOutcome.backToCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupViewModelProvider);
    final minutes = state.pending?.codeExpiresIn.inMinutes ?? 10;
    final canVerify =
        validateSixDigitCode(_code.text) == null &&
        !state.attemptCooldown.isActive;

    return FormPage(
      title: '이메일 인증',
      children: [
        Text(
          '${state.email}(으)로 보낸 6자리 인증 코드를 입력해 주세요.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '인증 코드는 $minutes분 동안 유효합니다.',
          style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: '인증 코드'),
        ),
        MessageText(state.errorMessage),
        MessageText(state.notice, isError: false),
        CooldownNotice(state.attemptCooldown),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '인증하고 가입 완료',
          isLoading: state.isSubmitting,
          onPressed: canVerify ? _verify : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: state.resendCooldown.isActive || state.isSubmitting
              ? null
              : ref.read(signupViewModelProvider.notifier).resend,
          child: const Text('인증 코드 다시 받기'),
        ),
        CooldownNotice(
          state.resendCooldown,
          activeText: (r) => '$r 후에 다시 받을 수 있습니다.',
        ),
      ],
    );
  }
}
