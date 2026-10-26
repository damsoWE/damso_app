import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/field_error_text.dart';
import '../../../core/widgets/form_layout.dart';
import '../domain/me.dart';
import 'me_view_model.dart';
import 'my_page_parts.dart';

/// C-9 계정 정보 (Figma 225-1658). 연락처 입력란은 없다(원칙 I).
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 정보')),
      body: AsyncView(
        value: ref.watch(meViewModelProvider),
        onRetry: ref.read(meViewModelProvider.notifier).refresh,
        data: (s) => _AccountForm(me: s.me),
      ),
    );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({required this.me});

  final Me me;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  late final _name = TextEditingController(text: widget.me.name)
    ..addListener(() => setState(() {}));
  bool _saved = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref.read(meViewModelProvider.notifier).updateName(_name.text);
    if (mounted) setState(() => _saved = ok);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meViewModelProvider).value;
    final me = state?.me ?? widget.me;
    final unchanged = _name.text.trim() == me.name;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('이메일', style: AppTextStyles.smallStrong.copyWith(color: AppColors.textSecondary)),
        Text(me.email, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        Text('역할', style: AppTextStyles.smallStrong.copyWith(color: AppColors.textSecondary)),
        Text(roleLabel(me.role), style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        FieldErrorText.pick(
          server: state?.fieldErrors['name'],
          client: _name.text.isEmpty ? null : validateName(_name.text),
        ),
        MessageText(state?.errorMessage),
        if (_saved && unchanged) const MessageText('저장했습니다.', isError: false),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '저장',
          isLoading: state?.isSubmitting ?? false,
          onPressed: validateName(_name.text) == null && !unchanged ? _save : null,
        ),
      ],
    );
  }
}
