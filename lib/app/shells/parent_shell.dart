import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inquiry/presentation/parent/parent_inquiries_view_model.dart';
import 'tab_shell.dart';

/// 학부모 탭 셸: 홈(F2-1) · 문의(F2-4) · 마이페이지(F2-7).
class ParentShell extends ConsumerWidget {
  const ParentShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabShell(
      shell: shell,
      // 홈·문의 탭으로 돌아오면 문의 목록을 다시 불러온다(FR-019).
      onTabEntered: (index) {
        if (index > 1) return;
        ref.invalidate(parentInquiriesViewModelProvider);
        ref.invalidate(parentInquiryDetailsProvider); // 펼친 카드의 옛 타임라인도 비운다
      },
    );
  }
}
