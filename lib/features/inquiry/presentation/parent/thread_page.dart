import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_tag.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../dial_launcher.dart';
import '../format.dart';
import '../stage_timeline.dart';
import 'follow_up_page.dart';
import 'thread_view_model.dart';
import 'urgent_notice_view.dart';

/// F4-1 문의 상세(스레드) (Figma 216-5241). 처음 문의·교사 답변·재문의를 시간순으로 보인다.
/// 보낸 글은 수정·삭제할 수 없고(원칙 III) 본문은 일반 Text 로만 그린다(원칙 VI).
/// 답변 작성자는 "담임 선생님"으로만 표시한다(원칙 I).
class ParentThreadPage extends ConsumerWidget {
  const ParentThreadPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = parentThreadViewModelProvider(inquiryId);
    final value = ref.watch(provider);
    final detail = value.value;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.summary.studentName ?? '')),
      body: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(provider),
        data: (d) => RefreshIndicator(
          onRefresh: ref.read(provider.notifier).reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final item in d.thread) ...[
                _ItemCard(item: item),
                const SizedBox(height: AppSpacing.md),
              ],
              if (d.answers.isEmpty) _Waiting(detail: d),
            ],
          ),
        ),
      ),
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () => context.push(
                        '/parent/inquiries/$inquiryId/follow-up',
                        extra: ParentFollowUpArgs(studentName: detail.summary.studentName),
                      ),
                      child: const Text('이어서 묻기'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => context.go('/parent/inquiries'),
                      child: const Text('문의 목록으로'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final ThreadItem item;

  @override
  Widget build(BuildContext context) {
    final (title, at, content, urgent, hotlines) = switch (item) {
      RootItem(:final content, :final submittedAt, :final urgent, :final hotlines) =>
        ('학부모 · 처음 문의', submittedAt, content, urgent, hotlines),
      FollowUpItem(:final content, :final submittedAt, :final urgent, :final hotlines) =>
        ('학부모 · 이어서 물음', submittedAt, content, urgent, hotlines),
      AnswerItem(:final content, :final sentAt) =>
        ('담임 선생님', sentAt, content, false, const <Hotline>[]),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: urgent ? AppColors.statusUrgent : AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.subtitle)),
              if (urgent) const AppTag(NoticeText.urgentLabel, tone: TagTone.urgent),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatDateTime(at),
            style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 본문은 일반 Text 로만 그린다(HTML·Markdown 금지).
          Text(content, style: AppTextStyles.body),
          if (urgent && hotlines.isNotEmpty) _Hotlines(hotlines: hotlines),
        ],
      ),
    );
  }
}

class _Hotlines extends ConsumerWidget {
  const _Hotlines({required this.hotlines});

  final List<Hotline> hotlines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDial = ref.watch(canDialProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text('도움이 필요하시다면', style: AppTextStyles.subtitle),
        for (final h in hotlines) ...[
          const SizedBox(height: AppSpacing.sm),
          HotlineCard(hotline: h, canDial: canDial),
        ],
      ],
    );
  }
}

/// 답변이 아직 없을 때 스레드 끝에 보이는 안내와 처음 문의 처리 단계(FR-004).
class _Waiting extends StatelessWidget {
  const _Waiting({required this.detail});

  final ParentInquiryDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('답변을 기다리고 있어요', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.md),
        StageTimeline(
          urgent: detail.summary.urgent,
          events: detail.timeline,
          answeredAt: detail.summary.lastAnsweredAt,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
