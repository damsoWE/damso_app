import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/push/pending_navigation.dart';
import '../../features/inquiry/presentation/parent/parent_inquiries_view_model.dart';
import 'tab_shell.dart';

/// 학부모 탭 셸: 홈(F2-1) · 문의(F2-4) · 마이페이지(F2-7).
class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  @override
  void initState() {
    super.initState();
    // 로그인 전에 답변 알림을 눌러 열었으면 탭 화면 위에 그 스레드를 띄운다(뒤로 가면 탭 화면).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(pendingNavigationProvider);
      if (pending == null) return;
      ref.read(pendingNavigationProvider.notifier).clear();
      context.push(pending);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TabShell(
      shell: widget.shell,
      // 홈·문의 탭으로 돌아오면 문의 목록을 다시 불러온다(FR-019).
      onTabEntered: (index) {
        if (index > 1) return;
        ref.invalidate(parentInquiriesViewModelProvider);
      },
    );
  }
}
