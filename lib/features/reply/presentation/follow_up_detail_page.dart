import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_tag.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/bottom_actions.dart';
import '../../../core/widgets/system_notice.dart';
import '../../inquiry/domain/notice_text.dart';
import '../../inquiry/presentation/format.dart';
import '../../inquiry/presentation/teacher/content_page.dart';
import '../../inquiry/presentation/teacher/refinement_view.dart';
import '../domain/answer_text.dart';
import '../domain/models.dart';
import 'follow_up_detail_view_model.dart';

/// F4-3b 재문의 상세 (Figma 323-1843). F3-2 와 같은 배치로, 제목은 "{문의 제목} - 재문의".
/// 학부모 이름·연락처는 없다(spec FR-024). "원문 보기"는 재문의 원문(F3-6, 323-1863)을 연다.
class FollowUpDetailPage extends ConsumerWidget {
  const FollowUpDetailPage({super.key, required this.args});

  final FollowUpArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUp = args.followUp;
    final provider = followUpDetailViewModelProvider((
      followUpId: followUp.inquiryId,
      urgent: followUp.urgent,
    ));
    final title = AnswerText.followUpTitle(args.rootTitle);
    final at = formatDateTime(followUp.submittedAt);
    final value = ref.watch(provider);
    final loaded = value.value;
    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세')),
      // Figma F4-3b: "원문 보기"·"답변 작성"은 하단 고정. 상세를 받은 뒤에만 보인다.
      bottomNavigationBar: loaded == null
          ? null
          : BottomActions(
              children: [
                OutlinedButton(
                  onPressed: () => _open(
                    context,
                    '/teacher/inquiries/${followUp.inquiryId}/content',
                    ContentArgs(
                      title: title,
                      header: '${args.studentName} 학부모 · $at',
                      answerTarget: args.canAnswer ? _target(loaded) : null,
                    ),
                  ),
                  child: const Text(AnswerText.viewOriginalButton),
                ),
                if (args.canAnswer)
                  FilledButton(
                    onPressed: () => _open(
                      context,
                      '/teacher/inquiries/${args.rootId}/answer',
                      _target(loaded),
                    ),
                    child: const Text(AnswerText.writeAnswerButton),
                  ),
              ],
            ),
      body: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(provider),
        data: (detail) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (detail is Refined) ...[
                const _Badge(NoticeText.refinedBadge),
                const SizedBox(height: AppSpacing.ms),
              ],
              Text(title, style: AppTextStyles.display),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AnswerText.followUpHeader(args.studentName, at),
                style: AppTextStyles.small.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              switch (detail) {
                Refined(:final refinement) => RefinementView(
                  refinement: refinement,
                ),
                NotRefined() => const SystemNotice(
                  AnswerText.followUpNotRefined,
                  icon: Icons.info_outline,
                ),
                Urgent() => const SystemNotice(
                  NoticeText.urgentDetailGuide,
                  icon: Icons.warning_amber_outlined,
                ),
              },
              const SizedBox(height: AppSpacing.md),
              Text(
                NoticeText.contentViewWillLog,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// "답변 작성"으로 넘길 값. 재문의 번역본이 있으면 그 요청사항을 함께 넘긴다.
  AnswerTarget _target(FollowUpDetail detail) {
    final requests = detail is Refined ? detail.refinement.requests : null;
    return AnswerTarget(
      inquiryId: args.rootId,
      studentName: args.studentName,
      title: args.rootTitle,
      requests: requests == null || requests.isEmpty ? null : requests,
      fromThread: true,
      lastSeenFollowUpId: args.lastSeenFollowUpId,
    );
  }

  /// 답변을 보내고 돌아오면 이 화면도 닫아 스레드로 돌아간다(research R14).
  Future<void> _open(BuildContext context, String path, Object extra) async {
    final sent = await context.push(path, extra: extra);
    if (sent is AnswerSent && context.mounted) context.pop(sent);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: AppTag(text, tone: TagTone.info),
  );
}
