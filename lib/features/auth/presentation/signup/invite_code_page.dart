import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/field_error_text.dart';
import '../../../../core/widgets/form_layout.dart';
import '../../../../core/widgets/invite_code_formatter.dart';
import 'signup_view_model.dart';

/// F1-1 초대코드 입력 (Figma 216-5050) · F1-2 코드 오류 (216-5060) · F1-2b 잠금 (216-5069).
/// 서버가 실패 횟수를 이메일 기준으로 세므로 이메일을 함께 받는다(api-v0.4).
class InviteCodePage extends ConsumerStatefulWidget {
  const InviteCodePage({super.key});

  @override
  ConsumerState<InviteCodePage> createState() => _InviteCodePageState();
}

class _InviteCodePageState extends ConsumerState<InviteCodePage> {
  late final _code = _controller(ref.read(signupViewModelProvider).inviteCode);
  late final _email = _controller(ref.read(signupViewModelProvider).email);

  TextEditingController _controller(String text) =>
      TextEditingController(text: text)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(signupViewModelProvider.notifier)
        .submitCode(code: _code.text, email: _email.text);
    if (outcome == SignupOutcome.next && mounted) {
      context.push('/signup/account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupViewModelProvider);
    final codeError = _code.text.length == 10
        ? validateInviteCode(_code.text)
        : null;
    final canSubmit =
        validateInviteCode(_code.text) == null &&
        validateEmail(_email.text) == null &&
        !state.attemptCooldown.isActive;

    return FormPage(
      title: '초대코드 입력',
      children: [
        const Text(
          '학교에서 받은 초대 코드 10자리와 가입할 이메일을 입력해 주세요.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _code,
          inputFormatters: const [InviteCodeFormatter()],
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: '초대 코드'),
        ),
        FieldErrorText.pick(
          server: state.fieldErrors['inviteCode'],
          client: codeError,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _email,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        FieldErrorText.pick(
          server: state.fieldErrors['email'],
          client: _email.text.isEmpty ? null : validateEmail(_email.text),
        ),
        MessageText(state.errorMessage),
        CooldownNotice(state.attemptCooldown),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '코드 확인',
          isLoading: state.isSubmitting,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
