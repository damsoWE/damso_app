import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import 'classroom_detail_view_model.dart';
import 'format.dart';

/// ADM-1 학급 상세·학생 명단 (Figma 224-1343) · ADM-2 교사 초대코드 발행 (224-1374).
class ClassroomDetailPage extends ConsumerWidget {
  const ClassroomDetailPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = classroomDetailViewModelProvider(classroomId);
    final detail = ref.watch(provider);
    final title = detail.whenOrNull(
      data: (d) => classroomLabel(d.classroom.grade, d.classroom.classNumber),
    );

    /// 미사용 코드가 있으면 재발행 확인(ADM-6)을 거치고, 없으면 바로 발행한다.
    Future<void> onIssue(InviteTarget target, {required bool reissue}) async {
      if (reissue) {
        context.push('/admin/invite/confirm', extra: target);
        return;
      }
      final result = await ref.read(provider.notifier).issue(target);
      if (!context.mounted) return;
      switch (result) {
        case Issued(:final code):
          context.push(
            '/admin/invite/issued',
            extra: IssuedInviteArgs(code: code, target: target),
          );
        case IssueFailed(:final message):
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(title ?? '학급 상세')),
      body: AsyncView(
        value: detail,
        onRetry: ref.read(provider.notifier).refresh,
        data: (d) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _HomeroomCard(
              detail: d,
              onIssue: () => onIssue(
                TeacherInviteTarget(classroomId),
                reissue: d.teacherCodeUnused,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      '/admin/classrooms/$classroomId/students/new',
                    ),
                    child: const Text('학생 등록'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      '/admin/classrooms/$classroomId/invite-codes',
                    ),
                    child: const Text('발행 현황'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('학생 명단 (${d.students.length}명)', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.sm),
            if (d.students.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('등록된 학생이 없습니다.'),
              ),
            for (final s in d.students)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.name),
                subtitle: Text(s.guardianLinked ? '보호자 연결됨' : '보호자 미연결'),
                trailing: s.guardianLinked
                    ? null
                    : TextButton(
                        onPressed: () => onIssue(
                          ParentInviteTarget(
                            classroomId,
                            studentId: s.studentId,
                            studentName: s.name,
                          ),
                          reissue: d.studentsWithUnusedCode.contains(s.studentId),
                        ),
                        child: Text(
                          d.studentsWithUnusedCode.contains(s.studentId)
                              ? '재발행'
                              : '학부모 코드 발행',
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeroomCard extends StatelessWidget {
  const _HomeroomCard({required this.detail, required this.onIssue});

  final ClassroomDetail detail;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    final assigned = detail.classroom.homeroomAssigned;
    return Card(
      color: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('담임', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(assigned ? '담임 선생님이 연결되어 있습니다.' : '담임 선생님이 아직 연결되지 않았습니다.'),
            if (!assigned) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: onIssue,
                child: Text(detail.teacherCodeUnused ? '교사 코드 재발행' : '교사 초대코드 발행'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
