import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_layout.dart';
import 'classroom_new_view_model.dart';

/// ADM-1c 학급 추가 (Figma 225-1862).
class ClassroomNewPage extends ConsumerWidget {
  const ClassroomNewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classroomNewViewModelProvider);
    final vm = ref.read(classroomNewViewModelProvider.notifier);

    Future<void> submit() async {
      if (await vm.submit() && context.mounted) context.pop();
    }

    return FormPage(
      title: '학급 추가',
      bottom: [
        SubmitButton(
          label: '학급 추가',
          isLoading: state.isSubmitting,
          onPressed: state.isValid ? submit : null,
        ),
      ],
      children: [
        DropdownButtonFormField<int>(
          initialValue: state.grade,
          decoration: const InputDecoration(labelText: '학년'),
          items: [
            for (var g = 1; g <= 6; g++)
              DropdownMenuItem(value: g, child: Text('$g학년')),
          ],
          onChanged: vm.setGrade,
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<int>(
          initialValue: state.classNumber,
          decoration: const InputDecoration(labelText: '반'),
          items: [
            for (var n = 1; n <= 20; n++)
              DropdownMenuItem(value: n, child: Text('$n반')),
          ],
          onChanged: vm.setClassNumber,
        ),
        MessageText(state.errorMessage),
      ],
    );
  }
}
