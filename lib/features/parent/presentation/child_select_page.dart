import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import 'parent_home_view_model.dart';

/// F2-1a 자녀 선택 (Figma 216-5183).
class ChildSelectPage extends ConsumerWidget {
  const ChildSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(parentHomeViewModelProvider);
    final vm = ref.read(parentHomeViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('자녀 선택')),
      body: AsyncView(
        value: home,
        onRetry: vm.refresh,
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final c in s.children)
              ListTile(
                title: Text(c.studentName),
                subtitle: Text('${c.classroom.grade}학년 ${c.classroom.classNumber}반'),
                trailing: c.studentId == s.selected?.studentId
                    ? const Icon(Icons.check, color: AppColors.brandPrimary)
                    : null,
                onTap: () {
                  vm.select(c.studentId);
                  context.pop();
                },
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => context.push('/parent/children/add'),
              child: const Text('자녀 추가 연결'),
            ),
          ],
        ),
      ),
    );
  }
}
