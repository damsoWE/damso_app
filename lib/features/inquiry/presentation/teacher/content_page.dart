import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import 'content_view_model.dart';

/// F3-6 원문 열람 (Figma 216-5653). 학부모가 쓴 원문을 그대로 일반 글자로 보인다.
/// 학부모 이름·연락처는 없다(FR-019). 답변 작성은 F4 가 하단에 더한다(FR-023).
class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contentViewModelProvider(inquiryId);
    return Scaffold(
      appBar: AppBar(title: const Text('원문')),
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
                '${s.studentName} · ${formatDateTime(s.submittedAt)}',
                style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  border: Border.all(color: AppColors.borderDefault),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('작성한 원문', style: AppTextStyles.subtitle),
                    const SizedBox(height: AppSpacing.sm),
                    // 일반 Text 만 쓴다(길게 눌러 복사하지 않음, FR-007).
                    Text(
                      d.content,
                      style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SystemNotice(NoticeText.contentViewedLogged),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('문의 상세로'),
              ),
            ],
          );
        },
      ),
    );
  }
}
