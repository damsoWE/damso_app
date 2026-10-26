import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/field_error_text.dart';
import '../../../../core/widgets/form_layout.dart';
import '../../domain/models.dart';
import 'signup_view_model.dart';

/// F1-3 계정 만들기 · 학부모 (Figma 216-5101) · F1-3a 교사 (225-1553).
/// 입력은 이름·이메일·비밀번호·약관 동의뿐이다(FR-014, 연락처 입력란 없음).
class SignupAccountPage extends ConsumerStatefulWidget {
  const SignupAccountPage({super.key});

  @override
  ConsumerState<SignupAccountPage> createState() => _SignupAccountPageState();
}

class _SignupAccountPageState extends ConsumerState<SignupAccountPage> {
  late final _name = _controller(ref.read(signupViewModelProvider).name);
  late final _email = _controller(ref.read(signupViewModelProvider).email);
  late final _password = _controller('');
  bool _termsAgreed = false;

  TextEditingController _controller(String text) =>
      TextEditingController(text: text)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(signupViewModelProvider.notifier)
        .submitAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          termsAgreed: _termsAgreed,
        );
    if (!mounted) return;
    switch (outcome) {
      case SignupOutcome.next:
        context.push('/signup/verify');
      case SignupOutcome.backToCode:
        context.pop();
      case SignupOutcome.stay:
        break;
    }
  }

  /// 입력을 시작한 필드만 앱 검증 안내를 보인다.
  String? _clientError(TextEditingController c, String? Function(String) v) =>
      c.text.isEmpty ? null : v(c.text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupViewModelProvider);
    final (title, intro) = switch (state.inviteRole) {
      InviteRole.parent => (
        '계정 만들기 · 학부모',
        '자녀와 연결된 초대 코드를 확인했어요. 보호자 정보를 입력해 주세요.',
      ),
      InviteRole.teacher => (
        '계정 만들기 · 교사',
        '담임 학급 초대 코드를 확인했어요. 선생님 정보를 입력해 주세요.',
      ),
      null => ('계정 만들기', '계정 정보를 입력해 주세요. 초대 코드는 가입할 때 함께 확인합니다.'),
    };
    final valid =
        validateName(_name.text) == null &&
        validateEmail(_email.text) == null &&
        validateNewPassword(_password.text) == null &&
        _termsAgreed;

    return FormPage(
      title: title,
      children: [
        Text(intro, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        FieldErrorText.pick(
          server: state.fieldErrors['name'],
          client: _clientError(_name, validateName),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        FieldErrorText.pick(
          server: state.fieldErrors['email'],
          client: _clientError(_email, validateEmail),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            helperText: '영문과 숫자를 포함해 8~64자',
          ),
        ),
        FieldErrorText.pick(
          server: state.fieldErrors['password'],
          client: _clientError(_password, validateNewPassword),
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _termsAgreed,
          onChanged: (v) => setState(() => _termsAgreed = v ?? false),
          title: const Text('이용약관 및 개인정보 처리방침에 동의합니다'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.push('/terms'),
            child: const Text('약관 보기'),
          ),
        ),
        MessageText(state.errorMessage),
        CooldownNotice(state.attemptCooldown),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '동의하고 계정 만들기',
          isLoading: state.isSubmitting,
          onPressed: valid && !state.attemptCooldown.isActive ? _submit : null,
        ),
      ],
    );
  }
}
