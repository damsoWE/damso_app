import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/system_notice.dart';
import '../../inquiry/presentation/format.dart';
import '../../inquiry/presentation/teacher/content_page.dart';
import '../domain/answer_text.dart';
import '../domain/models.dart';
import 'thread_view_model.dart';

/// F4-3 답변 전송 완료 · 스레드 (Figma 315-1789, 재문의가 있는 스레드 315-1822).
/// 하단 버튼은 "문의 목록으로" 하나다 — 앱에는 닫기 기능이 없다(spec FR-017).
/// 시스템 안내는 교사 메시지와 구분되는 SystemNotice 로 그린다(원칙 V).
class ThreadPage extends ConsumerWidget {
  const ThreadPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = threadViewModelProvider(inquiryId);
    final value = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(value.value?.title ?? '')),
      body: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(provider),
        data: (s) => RefreshIndicator(
          onRefresh: ref.read(provider.notifier).reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (s.detail.hasAnswers) const _AnsweredTag(),
              for (final entry in s.entries) ...[
                const SizedBox(height: AppSpacing.md),
                switch (entry) {
                  ParentCard() => _ParentCardView(card: entry, state: s),
                  AnswerCard() => _AnswerCardView(card: entry, teacherName: s.teacherName),
                },
                ..._timeLine(entry),
              ],
              if (s.detail.hasAnswers) ...[
                const SizedBox(height: AppSpacing.md),
                const SystemNotice(AnswerText.sentNotice, icon: Icons.check_circle_outline),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: FilledButton(
            onPressed: () => context.go('/teacher/inquiries'),
            child: const Text(AnswerText.toListButton),
          ),
        ),
      ),
    );
  }

  List<Widget> _timeLine(ThreadEntry entry) {
    final text = switch (entry) {
      AnswerCard() => AnswerText.sentAt(formatDateTime(entry.at)),
      ParentCard(:final unanswered, :final isFollowUp) when isFollowUp && unanswered =>
        AnswerText.followUpHint(formatDateTime(entry.at)),
      _ => null,
    };
    if (text == null) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(text, style: AppTextStyles.small.copyWith(color: AppColors.textSecondary)),
    ];
  }
}

/// "답변 완료" — 답변을 보냈다는 뜻이며 문의 종료가 아니다(앱·운영 모두 종료를 쓰지 않음, api-v0.8).
class _AnsweredTag extends StatelessWidget {
  const _AnsweredTag();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusSuccessSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          AnswerText.answeredTag,
          style: AppTextStyles.label.copyWith(color: AppColors.statusSuccess),
        ),
      ),
    );
  }
}

/// 최초 문의 카드는 카드 안 "원문 보기", 재문의 카드는 카드 전체를 눌러 재문의 상세로 간다.
/// 다녀오면(답변을 보내고 돌아온 경우 포함) 스레드를 다시 읽는다.
class _ParentCardView extends ConsumerWidget {
  const _ParentCardView({required this.card, required this.state});

  final ParentCard card;
  final ThreadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = card.requests;
    final rootId = state.detail.summary.inquiryId;
    Future<void> open(String path, Object extra) async {
      await context.push(path, extra: extra);
      if (context.mounted) ref.read(threadViewModelProvider(rootId).notifier).reload();
    }

    final followUp = card.followUp;
    final box = _CardBox(
      title: AnswerText.parentCardTitle(state.studentName, followUp: card.isFollowUp),
      children: [
        if (requests != null && requests.isNotEmpty)
          Text(requests, style: AppTextStyles.small.copyWith(color: AppColors.textSecondary)),
        if (!card.isFollowUp) ...[
          const SizedBox(height: AppSpacing.ms),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => open(
                '/teacher/inquiries/$rootId/content',
                ContentArgs(
                  title: state.title,
                  header:
                      '${state.studentName} 학부모 · ${formatDateTime(card.at)}',
                  answerTarget: AnswerTarget(
                    inquiryId: rootId,
                    studentName: state.studentName,
                    title: state.title,
                    requests: requests,
                    fromThread: true,
                  ),
                ),
              ),
              child: const Text(AnswerText.viewOriginalButton),
            ),
          ),
        ],
      ],
    );
    if (followUp == null) return box;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => open(
        '/teacher/inquiries/$rootId/follow-ups/${followUp.inquiryId}',
        FollowUpArgs(
          rootId: rootId,
          studentName: state.studentName,
          rootTitle: state.title,
          followUp: followUp,
        ),
      ),
      child: box,
    );
  }
}

class _AnswerCardView extends StatelessWidget {
  const _AnswerCardView({required this.card, required this.teacherName});

  final AnswerCard card;
  final String? teacherName;

  @override
  Widget build(BuildContext context) => _CardBox(
    title: AnswerText.answerCardTitle(teacherName),
    children: [
      // 교사 자신이 보낸 본문. 일반 Text 로만, 수정·삭제 버튼은 없다(FR-016).
      Text(card.content, style: AppTextStyles.small.copyWith(color: AppColors.textSecondary)),
    ],
  );
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      border: Border.all(color: AppColors.borderDefault),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.subtitle),
        if (children.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    ),
  );
}
