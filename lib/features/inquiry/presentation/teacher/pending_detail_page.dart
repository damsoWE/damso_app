import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import '../stage_timeline.dart';

/// 일반 문의 상세(본문 없음). 원문은 부르지 않는다 — 열람 기록이 남기 때문이다(FR-024).
final _pendingDetailProvider = FutureProvider.autoDispose
    .family<TeacherInquiryDetail, String>(
      (ref, id) => ref.watch(teacherInquiryRepositoryProvider).detail(id),
    );

/// 일반 문의 자리 화면. 정리본(F3-2)·원문 확인 필요(F3-3)·원문 열람(F3-6)은 F3 에서 바뀐다.
class PendingDetailPage extends ConsumerWidget {
  const PendingDetailPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _pendingDetailProvider(inquiryId);
    return Scaffold(
      appBar: AppBar(title: const Text('문의')),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (d) {
          final s = d.summary;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(s.title, style: AppTextStyles.display),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${s.studentName} · ${formatDateTime(s.submittedAt)} 접수',
                style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              const SystemNotice(NoticeText.pendingDetail, icon: Icons.info_outline),
              const SizedBox(height: AppSpacing.lg),
              StageTimeline(urgent: false, events: d.timeline),
            ],
          );
        },
      ),
    );
  }
}
