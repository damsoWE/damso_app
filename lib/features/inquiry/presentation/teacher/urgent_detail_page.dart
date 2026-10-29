import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../reply/domain/answer_text.dart';
import '../../../reply/domain/models.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import '../stage_timeline.dart';
import 'urgent_detail_view_model.dart';

/// F3-5 긴급 문의 상세 (Figma 224-1245). 정리 없이 학부모가 쓴 원문 그대로를 보인다.
/// 학부모 이름·연락처는 없다(FR-023). 하단 "답변 작성"은 F4(specs/004 FR-002)가 더했다.
class UrgentDetailPage extends ConsumerWidget {
  const UrgentDetailPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = urgentDetailViewModelProvider(inquiryId);
    return Scaffold(
      appBar: AppBar(title: const Text(NoticeText.urgentLabel)),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (d) {
          final s = d.detail.summary;
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
              const SystemNotice(
                NoticeText.urgentDetailGuide,
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                color: AppColors.bgSurface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '원문',
                        style: AppTextStyles.smallStrong.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // 일반 Text 만 쓴다(길게 눌러 복사하지 않음, plan 렌더링 기준).
                      Text(d.content, style: AppTextStyles.body),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SystemNotice(NoticeText.contentViewLogged, icon: Icons.info_outline),
              const SizedBox(height: AppSpacing.lg),
              StageTimeline(
                urgent: true,
                events: d.detail.timeline,
                answeredAt: d.detail.summary.lastAnsweredAt,
              ),
              // "답변 작성"(specs/004 FR-002). 긴급은 정리본이 없어 요청사항 없이 간다.
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.push(
                  '/teacher/inquiries/$inquiryId/answer',
                  extra: AnswerTarget(
                    inquiryId: inquiryId,
                    studentName: s.studentName,
                    title: s.title,
                  ),
                ),
                child: const Text(AnswerText.writeAnswerButton),
              ),
            ],
          );
        },
      ),
    );
  }
}
