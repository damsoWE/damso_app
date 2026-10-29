import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_layout.dart';
import 'classroom_detail_view_model.dart';

/// ADM-6 코드 재발행 확인 (Figma 216-5761). 대상은 extra 로만 받는다.
class ReissueConfirmPage extends ConsumerStatefulWidget {
  const ReissueConfirmPage({super.key, required this.target});

  final InviteTarget? target;

  @override
  ConsumerState<ReissueConfirmPage> createState() => _ReissueConfirmPageState();
}

class _ReissueConfirmPageState extends ConsumerState<ReissueConfirmPage> {
  bool _issuing = false;
  String? _error;

  Future<void> _issue(InviteTarget target) async {
    setState(() {
      _issuing = true;
      _error = null;
    });
    final result = await ref
        .read(classroomDetailViewModelProvider(target.classroomId).notifier)
        .issue(target);
    if (!mounted) return;
    switch (result) {
      case Issued(:final code):
        // 뒤로 가기로 확인 화면에 돌아오지 않게 교체한다.
        context.pushReplacement(
          '/admin/invite/issued',
          extra: IssuedInviteArgs(code: code, target: target),
        );
      case IssueFailed(:final message):
        setState(() {
          _issuing = false;
          _error = message;
        });
      case IssueBusy():
        setState(() => _issuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target == null) {
      return FormPage(
        title: '코드 재발행',
        children: [
          const Text('재발행할 대상을 다시 선택해 주세요.'),
          TextButton(onPressed: () => context.pop(), child: const Text('뒤로')),
        ],
      );
    }
    final who = switch (target) {
      TeacherInviteTarget() => '담임 교사 초대 코드',
      ParentInviteTarget(:final studentName) => '$studentName 학생의 학부모 초대 코드',
    };
    return FormPage(
      title: '코드 재발행',
      bottom: [
        OutlinedButton(
          onPressed: _issuing ? null : () => context.pop(),
          child: const Text('취소'),
        ),
        SubmitButton(
          label: '새 코드 발행',
          isLoading: _issuing,
          onPressed: () => _issue(target),
        ),
      ],
      children: [
        Text('$who를 새로 발행할까요?', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '이전 코드는 즉시 무효가 됩니다.',
          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.statusUrgentText),
        ),
        MessageText(_error),
      ],
    );
  }
}
