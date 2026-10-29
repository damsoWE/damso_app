import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/inquiry_status_view_model.dart';
import 'tab_shell.dart';

/// 관리자 탭 셸: 홈(ADM-1a) · 문의(ADM-4 문의 현황) · 마이페이지(ADM-7), specs/006 research R3.
/// 문의 탭으로 돌아오면 현황을 다시 불러온다(FR-007).
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabShell(
      shell: shell,
      onTabEntered: (index) {
        if (index == 1) ref.invalidate(inquiryStatusViewModelProvider);
      },
    );
  }
}
