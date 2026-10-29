import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/cooldown.dart';
import '../../../core/widgets/form_layout.dart';
import '../../../core/widgets/invite_code_formatter.dart';
import 'add_child_view_model.dart';

/// F1-5 자녀 추가 · 초대코드 입력 (Figma 225-1692).
class AddChildPage extends ConsumerStatefulWidget {
  const AddChildPage({super.key});

  @override
  ConsumerState<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends ConsumerState<AddChildPage> {
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

  Future<void> _submit() async {
    final ok = await ref.read(addChildViewModelProvider.notifier).submit(_code.text);
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addChildViewModelProvider);
    final clientError = _code.text.length == 10 ? validateInviteCode(_code.text) : null;
    final canSubmit =
        _code.text.length == 10 && clientError == null && !state.cooldown.isActive;

    return FormPage(
      title: '자녀 추가',
      bottom: [
        SubmitButton(
          label: '코드 확인',
          isLoading: state.isSubmitting,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
      children: [
        const Text('자녀의 학부모 초대 코드 10자리를 입력해 주세요.', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _code,
          inputFormatters: const [InviteCodeFormatter()],
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: '초대 코드', errorText: clientError),
        ),
        MessageText(state.errorMessage),
        CooldownNotice(state.cooldown),
      ],
    );
  }
}
