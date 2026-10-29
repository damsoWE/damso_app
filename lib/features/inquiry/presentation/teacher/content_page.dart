import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../../reply/domain/answer_text.dart';
import '../../../reply/domain/models.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import 'content_view_model.dart';

/// 재문의·스레드에서 원문 열람을 열 때 넘기는 값(specs/004 research R13).
/// 제목·머리 줄을 그대로 쓰고, "답변 작성"은 [answerTarget] 으로 간다(없으면 버튼을 숨긴다).
class ContentArgs {
  const ContentArgs({required this.title, required this.header, this.answerTarget});

  final String title;
  final String header;
  final AnswerTarget? answerTarget;
}

/// F3-6 원문 열람 (Figma 216-5653, 재문의 323-1863). 학부모가 쓴 원문을 그대로 일반 글자로 보인다.
/// 학부모 이름·연락처는 없다(FR-019). 하단 "답변 작성"은 F4(specs/004 FR-002)가 더했다.
/// 머리 줄은 상세 화면이 넘긴 [summary] 또는 [args] 로 그린다. 둘 다 없으면(주소로 바로 연 경우)
/// 머리 줄과 답변 작성 없이 원문만.
class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, required this.inquiryId, this.summary, this.args});

  final String inquiryId;
  final TeacherInquirySummary? summary;
  final ContentArgs? args;

  /// "답변 작성"으로 넘길 값.
  AnswerTarget? get _answerTarget {
    final a = args;
    if (a != null) return a.answerTarget;
    final s = summary;
    if (s == null) return null;
    return AnswerTarget(inquiryId: s.inquiryId, studentName: s.studentName, title: s.title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contentViewModelProvider(inquiryId);
    final s = summary;
    final title = args?.title ?? s?.title;
    final header = args?.header ??
        (s == null ? null : '${s.studentName} · ${formatDateTime(s.submittedAt)}');
    final target = _answerTarget;
    return Scaffold(
      appBar: AppBar(title: const Text('원문')),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (content) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (title != null) ...[
                Text(title, style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (header != null) ...[
                Text(
                  header,
                  style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
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
                      content,
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
              if (target != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    final sent = await context.push(
                      '/teacher/inquiries/${target.inquiryId}/answer',
                      extra: target,
                    );
                    // 스레드에서 와서 답변을 보냈다 — 이 화면도 닫아 스레드로 돌아간다(specs/004 R14).
                    if (sent is AnswerSent && context.mounted) context.pop(sent);
                  },
                  child: const Text(AnswerText.writeAnswerButton),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
