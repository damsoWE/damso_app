import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import 'children_view_model.dart';

/// F1-4 연결된 자녀 (Figma 224-1210).
class ChildrenPage extends ConsumerWidget {
  const ChildrenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('연결된 자녀')),
      body: AsyncView(
        value: ref.watch(childrenViewModelProvider),
        onRetry: ref.read(childrenViewModelProvider.notifier).refresh,
        data: (children) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (children.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('연결된 자녀가 없습니다.'),
              ),
            for (final c in children)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.studentName),
                subtitle: Text(
                  '${c.classroom.grade}학년 ${c.classroom.classNumber}반 · '
                  '${c.teacher == null ? '담임 미연결' : '담임 ${c.teacher!.displayName}'}',
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.push('/parent/children/add'),
              child: const Text('초대코드로 자녀 추가'),
            ),
          ],
        ),
      ),
    );
  }
}
