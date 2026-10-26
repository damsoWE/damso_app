import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_layout.dart';
import '../domain/validators.dart';
import 'students_new_view_model.dart';

/// ADM-5 학생 등록 (Figma 216-5736) · ADM-5a 학생 등록 완료 (216-5748).
class StudentsNewPage extends ConsumerStatefulWidget {
  const StudentsNewPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  ConsumerState<StudentsNewPage> createState() => _StudentsNewPageState();
}

class _StudentsNewPageState extends ConsumerState<StudentsNewPage> {
  final _names = TextEditingController();

  @override
  void initState() {
    super.initState();
    _names.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = studentsNewViewModelProvider(widget.classroomId);
    final state = ref.watch(provider);
    final registered = state.registered;

    if (registered != null) {
      return FormPage(
        title: '학생 등록 완료',
        children: [
          Text('학생 ${registered.length}명을 등록했습니다.', style: AppTextStyles.subtitle),
          const SizedBox(height: AppSpacing.sm),
          for (final s in registered) Text('· ${s.name}', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          const Text('학생 명단에서 학부모 초대코드를 발행할 수 있습니다.'),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: () => context.pop(), child: const Text('학급 명단으로')),
        ],
      );
    }

    final input = parseStudentNames(_names.text);
    return FormPage(
      title: '학생 등록',
      children: [
        const Text('학생 이름을 한 줄에 한 명씩 입력해 주세요. 한 번에 40명까지 등록할 수 있습니다.'),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _names,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(
            labelText: '학생 이름',
            alignLabelWithHint: true,
            helperText: '입력한 학생 ${input.names.length}명',
          ),
        ),
        MessageText(state.errorMessage),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: '등록',
          isLoading: state.isSubmitting,
          onPressed: input.error == null
              ? () => ref.read(provider.notifier).submit(_names.text)
              : null,
        ),
      ],
    );
  }
}
