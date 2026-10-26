import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../domain/child.dart';
import 'parent_home_view_model.dart';

/// F2-1 학부모 홈 (Figma 216-5162) · F2-1b 빈 상태 (216-5199).
/// 문의 작성·최근 문의 영역은 F2 범위라 두지 않는다(FR-028). 담임 이메일은 없다.
class ParentHomePage extends ConsumerWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(parentHomeViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('학부모 홈'),
        actions: [
          IconButton(
            tooltip: '마이페이지',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/parent/me'),
          ),
        ],
      ),
      body: AsyncView(
        value: home,
        onRetry: ref.read(parentHomeViewModelProvider.notifier).refresh,
        isEmpty: (s) => s.selected == null,
        empty: (_) => const _NoChild(),
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _ChildCard(child: s.selected!, canSwitch: true),
            const SizedBox(height: AppSpacing.md),
            _TeacherCard(teacher: s.selected!.teacher),
          ],
        ),
      ),
    );
  }
}

class _NoChild extends StatelessWidget {
  const _NoChild();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('연결된 자녀가 없습니다.', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.sm),
            const Text('학교에서 받은 초대 코드로 자녀를 연결해 주세요.', textAlign: TextAlign.center),
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

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.canSwitch});

  final Child child;
  final bool canSwitch;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.bgSurface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        title: Text(child.studentName, style: AppTextStyles.title),
        subtitle: Text('${child.classroom.grade}학년 ${child.classroom.classNumber}반'),
        trailing: canSwitch ? const Text('자녀 선택') : null,
        onTap: canSwitch ? () => context.push('/parent/children/select') : null,
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher});

  final TeacherPublicProfile? teacher;

  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return Card(
      color: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('담임 선생님', style: AppTextStyles.smallStrong.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            if (t == null)
              const Text('담임 선생님이 아직 연결되지 않았습니다.', style: AppTextStyles.body)
            else ...[
              Text(t.displayName, style: AppTextStyles.subtitle),
              if (t.introduction.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(t.introduction, style: AppTextStyles.body),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
