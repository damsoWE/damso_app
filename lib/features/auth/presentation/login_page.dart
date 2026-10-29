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

    final secondaryLink = TextButton.styleFrom(foregroundColor: AppColors.textSecondary);

    return FormPage(
      // 세션 만료로 바로 열리면 뒤로 갈 화면이 없다. 그래도 Figma 처럼 뒤로 아이콘을 두고 시작 화면으로 보낸다.
      leading: context.canPop() ? null : BackButton(onPressed: () => context.go('/')),
      bottom: [
        SubmitButton(
          label: '로그인',
          isLoading: state.isSubmitting,
          onPressed: state.cooldown.isActive ? null : _submit,
        ),
        TextButton(
          onPressed: () => context.push('/signup'),
          style: secondaryLink.copyWith(
            textStyle: const WidgetStatePropertyAll(AppTextStyles.small),
          ),
          child: const Text('계정이 없나요? 초대코드로 가입하기'),
        ),
      ],
      children: [
        Text('다시 오신 걸 환영해요', style: AppTextStyles.display.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '가입한 이메일과 비밀번호로 로그인해 주세요.',
          style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _LabeledField(
          label: '이메일',
          child: TextField(
            controller: _email,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
        ),
        FieldErrorText(state.fieldErrors['email']),
        const SizedBox(height: AppSpacing.ms),
        _LabeledField(
          label: '비밀번호',
          child: TextField(
            controller: _password,
            autofillHints: const [AutofillHints.password],
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _submit(),
          ),
        ),
        FieldErrorText(state.fieldErrors['password']),
        MessageText(state.errorMessage),
        CooldownNotice(state.cooldown),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => context.push('/password-reset'),
            style: secondaryLink.copyWith(
              textStyle: const WidgetStatePropertyAll(AppTextStyles.smallStrong),
            ),
            child: const Text('비밀번호 재설정'),
          ),
        ),
      ],
    );
  }
}

/// Figma Input: 입력칸 위에 따로 붙는 라벨(`담소/Label`). 화면 낭독기는 입력칸 이름으로 읽는다.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(label, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(label: label, child: child),
      ],
    );
  }
}
