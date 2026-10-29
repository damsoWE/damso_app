import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/bottom_actions.dart';
import '../../../core/widgets/field_error_text.dart';
import '../../../core/widgets/form_layout.dart';
import '../domain/models.dart';
import '../domain/validators.dart';
import 'profile_edit_view_model.dart';

/// F3-9 공개 프로필 편집 (Figma 224-1317).
class ProfileEditPage extends ConsumerWidget {
  const ProfileEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(profileEditViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('공개 프로필')),
      body: AsyncView(
        value: value,
        onRetry: ref.read(profileEditViewModelProvider.notifier).refresh,
        data: (s) => _ProfileForm(initial: s.profile),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});

  final TeacherProfile initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _name = TextEditingController(text: widget.initial.displayName)
    ..addListener(() => setState(() {}));
  late final _intro = TextEditingController(text: widget.initial.introduction)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _name.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref
        .read(profileEditViewModelProvider.notifier)
        .save(displayName: _name.text, introduction: _intro.text);
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditViewModelProvider).value;
    final introLength = _intro.text.trim().runes.length;
    final over = introLength > introductionMaxLength;
    final valid =
        validateDisplayName(_name.text) == null &&
        validateIntroduction(_intro.text) == null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text('학부모에게 보이는 이름과 소개입니다.', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '표시 이름'),
              ),
              FieldErrorText.pick(
                server: state?.fieldErrors['displayName'],
                client: _name.text.isEmpty
                    ? null
                    : validateDisplayName(_name.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _intro,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '소개',
                  counterText: '$introLength/$introductionMaxLength',
                  counterStyle: over
                      ? AppTextStyles.micro.copyWith(
                          color: AppColors.statusUrgentText,
                        )
                      : null,
                ),
              ),
              FieldErrorText.pick(
                server: state?.fieldErrors['introduction'],
                client: validateIntroduction(_intro.text),
              ),
              MessageText(state?.errorMessage),
            ],
          ),
        ),
        // Figma F3-9: 저장은 하단 고정.
        BottomActions(
          children: [
            SubmitButton(
              label: '저장',
              isLoading: state?.isSaving ?? false,
              onPressed: valid ? _save : null,
            ),
          ],
        ),
      ],
    );
  }
}
