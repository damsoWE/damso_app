import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../domain/models.dart';
import 'urgent_notice_view.dart';
import 'urgent_notice_view_model.dart';

/// 문의 탭의 긴급 카드에서 여는 긴급 전달 안내(F2-3 계열).
class UrgentNoticePage extends ConsumerWidget {
  const UrgentNoticePage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = urgentNoticeViewModelProvider(inquiryId);
    return Scaffold(
      appBar: AppBar(title: const Text('긴급 문의')),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            switch (detail.outcome) {
              UrgentNotice(:final hotlines) => UrgentNoticeView(hotlines: hotlines),
              _ => const Text('긴급 문의가 아닙니다.'),
            },
          ],
        ),
      ),
    );
  }
}
