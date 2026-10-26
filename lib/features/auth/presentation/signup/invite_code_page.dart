import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/form_layout.dart';
import '../../../../core/widgets/invite_code_formatter.dart';
import 'signup_view_model.dart';

/// F1-1 초대코드 입력 (Figma 216-5050) · F1-2 코드 오류 (216-5060) · F1-2b 잠금 (216-5069).
class InviteCodePage extends ConsumerStatefulWidget {
  const InviteCodePage({super.key});

  @override
  ConsumerState<InviteCodePage> createState() => _InviteCodePageState();
}

class _InviteCodePageState extends ConsumerState<InviteCodePage> {
  late final _code = TextEditingController(
    text: ref.read(signupViewModelProvider).inviteCode,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(signupViewModelProvider.notifier)
        .submitCode(_code.text);
    if (outcome == SignupOutcome.next && mounted) {
      context.push('/signup/account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupViewModelProvider);
    final clientError = _code.text.length == 10
        ? validateInviteCode(_code.text)
        : null;
    final canSubmit =
        _code.text.length == 10 &&
        clientError == null &&
        !state.attemptCooldown.isActive;

    return FormPage(
      title: '초대코드 입력',
      children: [
        const Text(
          '학교에서 받은 초대 코드 10자리를 입력해 주세요.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _code,
          inputFormatters: const [InviteCodeFormatter()],
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '초대 코드',
            errorText: clientError,
          ),
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
