import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/field_error_text.dart';
import '../../../core/widgets/form_layout.dart';
import 'me_view_model.dart';

/// C-8 회원 탈퇴 확인 (Figma 225-1623). 임시 안내 문안. 슈퍼 관리자는 라우터가 막는다.
class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meViewModelProvider).value;
    final submitting = state?.isSubmitting ?? false;
    return FormPage(
      title: '회원 탈퇴',
      children: [
        const Text('탈퇴하면 이 계정으로 다시 로그인할 수 없습니다.', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          '연결된 학급·자녀 정보가 해제됩니다. 보낸 문의와 답변 기록은 학교의 기록 보존 기준에 따라 남습니다. (임시 문안)',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _password,
          autofillHints: const [AutofillHints.password],
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: '현재 비밀번호'),
        ),
        FieldErrorText(state?.fieldErrors['password']),
        MessageText(state?.errorMessage),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '탈퇴하기',
          isLoading: submitting,
          onPressed: state == null
              ? null
              : () => ref.read(meViewModelProvider.notifier).withdraw(_password.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: submitting ? null : () => context.pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
