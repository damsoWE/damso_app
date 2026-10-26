import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import 'tab_shell.dart';

/// 교사 탭 셸: 홈(F3-4) · 문의(F3-1) · 마이페이지(F3-7).
/// 앱이 다시 앞으로 오거나 홈·문의 탭으로 돌아오면 문의 목록을 다시 불러온다(FR-020a).
class TeacherShell extends ConsumerStatefulWidget {
  const TeacherShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshInquiries);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshInquiries() =>
      ref.read(teacherInquiriesViewModelProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    return TabShell(
      shell: widget.shell,
      onTabEntered: (index) {
        if (index <= 1) _refreshInquiries();
      },
    );
  }
}
