import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_layout.dart';
import 'classroom_detail_view_model.dart';
import 'format.dart';

/// ADM-3 학부모 코드 발행 완료 (Figma 216-5828) · ADM-3t 교사 코드 발행 완료 (227-1743).
/// 코드 원문은 extra 로 받은 값만 쓰고 어디에도 보관하지 않는다(FR-035, research R11).
/// 관리자가 직접 누른 복사만 허용한다(spec Clarifications 2026-10-26).
class InviteIssuedPage extends StatelessWidget {
  const InviteIssuedPage({super.key, required this.args});

  final IssuedInviteArgs? args;

  @override
  Widget build(BuildContext context) {
    final a = args;
    if (a == null) {
      return FormPage(
        title: '코드 발행 완료',
        children: [
          const Text('다시 볼 수 없는 코드입니다.'),
          TextButton(onPressed: () => context.pop(), child: const Text('뒤로')),
        ],
      );
    }
    final (title, who) = switch (a.target) {
      TeacherInviteTarget() => ('교사 코드 발행 완료', '담임 교사 초대 코드'),
      ParentInviteTarget(:final studentName) => (
        '학부모 코드 발행 완료',
        '$studentName 학생의 학부모 초대 코드',
      ),
    };
    return FormPage(
      title: title,
      children: [
        Text(who, style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.brandAccentSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: SelectableText(
            a.code.code,
            textAlign: TextAlign.center,
            style: AppTextStyles.display.copyWith(letterSpacing: 4),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('만료: ${formatDateTime(a.code.expiresAt)}', style: AppTextStyles.small),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '이 화면을 떠나면 코드를 다시 볼 수 없습니다.',
          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.statusUrgentText),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: a.code.code));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('복사했습니다.')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('복사'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: () => context.go('/admin/classrooms/${a.target.classroomId}'),
          child: const Text('목록으로'),
        ),
      ],
    );
  }
}
