import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../inquiry/presentation/parent/compose_view_model.dart';
import '../../inquiry/presentation/parent/home_inquiry_section.dart';
import '../../notification/presentation/device_registrar.dart';
import '../domain/child.dart';
import 'parent_home_view_model.dart';

/// F2-1 학부모 홈 (Figma 216-5162) · F2-1b 빈 상태 (216-5199).
/// 고른 자녀·담임 카드, 최근 문의(F2 FR-017), 문의 작성 버튼. 담임 이메일은 없다.
class ParentHomePage extends ConsumerStatefulWidget {
  const ParentHomePage({super.key});

  @override
  ConsumerState<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends ConsumerState<ParentHomePage> {
  @override
  void initState() {
    super.initState();
    // 답변 도착 알림 권한은 홈 첫 진입 때, 기기에서 아직 정하지 않았을 때만 묻는다(FR-016).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(deviceRegistrarProvider).requestPermissionIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(parentHomeViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('학부모 홈'),
      ),
      body: AsyncView(
        value: home,
        onRetry: ref.read(parentHomeViewModelProvider.notifier).refresh,
        isEmpty: (s) => s.selected == null,
        empty: (_) => const _NoChild(),
        data: (s) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _ChildCard(child: s.selected!, canSwitch: true),
                  const SizedBox(height: AppSpacing.md),
                  _TeacherCard(teacher: s.selected!.teacher),
                  const SizedBox(height: AppSpacing.lg),
                  HomeInquirySection(studentId: s.selected!.studentId),
                ],
              ),
            ),
            _ComposeButton(child: s.selected!),
          ],
        ),
      ),
    );
  }
}

/// 고른 자녀로 문의 작성(F2-2). 담임이 없으면 열지 않고 안내만 보인다(FR-003).
class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final blocked = composeBlockedReason(child);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  blocked,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
                ),
              ),
            FilledButton(
              onPressed: blocked != null
                  ? null
                  : () => context.push('/parent/inquiries/new', extra: child),
              child: Text('${child.studentName} 학생 문의 작성'),
            ),
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
