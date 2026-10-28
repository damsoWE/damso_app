import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import 'general_detail_view_model.dart';
import 'refinement_view.dart';

/// 일반 문의 상세. 서버 정리 상태에 따라 F3-2 정리본(Figma 216-5607) · F3-3 원문 확인 필요
/// (216-5627) · F3-3a 다시 정리하는 중(216-5640) · 정리 중(216-5640 배치) 중 하나를 그린다.
/// 학부모 이름·연락처는 없다(FR-019). 답변 작성 버튼은 F4 가 하단 버튼 줄에 더한다(FR-023).
class GeneralDetailPage extends ConsumerWidget {
  const GeneralDetailPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = generalDetailViewModelProvider(inquiryId);
    ref.listen(provider, (previous, next) {
      // 긴급 문의였다 — 긴급 상세(F3-5)로 한 번만 바꾼다(그리는 중에 이동하지 않는다, 코드 리뷰 반영).
      if (next.value?.view is UrgentRedirect &&
          previous?.value?.view is! UrgentRedirect) {
        context.replace('/teacher/inquiries/$inquiryId/urgent');
        return;
      }
      final message = next.value?.message;
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(provider.notifier).clearMessage();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세')),
      body: AsyncView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (s) {
          final view = s.view;
          if (view is UrgentRedirect) return const SizedBox.shrink(); // ref.listen 이 옮긴다
          final notifier = ref.read(provider.notifier);
          return RefreshIndicator(
            onRefresh: notifier.recheck,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: switch (view) {
                Refined() => _refined(view),
                NeedsOriginal() => _needsOriginal(view, s, notifier),
                Refining() => _refining(context, view, s, notifier),
                UrgentRedirect() => const [],
              },
            ),
          );
        },
      ),
    );
  }

  /// 원문 열람(F3-6)으로 가는 곳은 여기 한 곳이다. 돌아오면 상태를 다시 읽는다(FR-018).
  Widget _contentButton(TeacherInquirySummary summary) => Consumer(
    builder: (context, ref, _) => OutlinedButton(
      onPressed: () async {
        await context.push('/teacher/inquiries/$inquiryId/content', extra: summary);
        if (context.mounted) {
          ref.read(generalDetailViewModelProvider(inquiryId).notifier).recheck();
        }
      },
      child: const Text('원문 보기'),
    ),
  );

  List<Widget> _refined(Refined view) => [
    Row(
      children: [
        const _Badge(
          NoticeText.refinedBadge,
          background: AppColors.statusInfoSoft,
          foreground: AppColors.statusInfo,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          NoticeText.translationLabel,
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.ms),
    Text(view.refinement.title, style: AppTextStyles.display),
    _HeaderLine(view.detail.summary),
    const SizedBox(height: AppSpacing.md),
    RefinementView(refinement: view.refinement),
    const SizedBox(height: AppSpacing.md),
    const _LogHint(),
    const SizedBox(height: AppSpacing.lg),
    _contentButton(view.detail.summary),
  ];

  List<Widget> _needsOriginal(
    NeedsOriginal view,
    GeneralDetailState s,
    GeneralDetailViewModel notifier,
  ) => [
    const _Badge(
      NoticeText.needsOriginalBadge,
      background: AppColors.statusWarningSoft,
      foreground: AppColors.statusWarning,
    ),
    const SizedBox(height: AppSpacing.ms),
    const Text(NoticeText.needsOriginalHeading, style: AppTextStyles.display),
    _HeaderLine(view.detail.summary),
    const SizedBox(height: AppSpacing.md),
    // 정리 결과는 어떤 형태로도 두지 않는다(FR-010, 원칙 IV).
    const SystemNotice(NoticeText.refinementFailed, icon: Icons.warning_amber_outlined),
    const SizedBox(height: AppSpacing.md),
    _contentButton(view.detail.summary),
    const SizedBox(height: AppSpacing.ms),
    if (view.detail.retryAvailable)
      OutlinedButton(
        onPressed: s.isRetrying ? null : notifier.retry,
        child: s.isRetrying
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(NoticeText.retryButton),
      )
    else
      const SystemNotice(NoticeText.retryLimitReached, icon: Icons.info_outline),
    const SizedBox(height: AppSpacing.md),
    const _LogHint(),
  ];

  /// 정리 중과 다시 정리하는 중(F3-3a)은 배지·제목·남은 재요청 카드만 다르다.
  /// 저절로 바뀌지 않으므로 다시 확인을 눌러야 한다(FR-012).
  List<Widget> _refining(
    BuildContext context,
    Refining view,
    GeneralDetailState s,
    GeneralDetailViewModel notifier,
  ) => [
    _Badge(
      view.afterRetry ? NoticeText.retryingBadge : NoticeText.refiningBadge,
      background: AppColors.statusInfoSoft,
      foreground: AppColors.statusInfo,
    ),
    const SizedBox(height: AppSpacing.ms),
    Text(
      view.afterRetry ? NoticeText.retryingHeading : NoticeText.refiningHeading,
      style: AppTextStyles.display,
    ),
    _HeaderLine(view.detail.summary),
    const SizedBox(height: AppSpacing.md),
    const SystemNotice(NoticeText.refiningGuide, icon: Icons.info_outline),
    const SizedBox(height: AppSpacing.md),
    _contentButton(view.detail.summary),
    const SizedBox(height: AppSpacing.ms),
    OutlinedButton(
      onPressed: s.isRechecking ? null : notifier.recheck,
      child: s.isRechecking
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(NoticeText.recheckButton),
    ),
    if (view.afterRetry) ...[
      const SizedBox(height: AppSpacing.md),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(NoticeText.retryRemainingTitle, style: AppTextStyles.subtitle),
            SizedBox(height: AppSpacing.xs),
            Text(NoticeText.retryRemainingNone, style: AppTextStyles.small),
          ],
        ),
      ),
    ],
    const SizedBox(height: AppSpacing.lg),
    FilledButton(
      onPressed: () => context.go('/teacher/inquiries'),
      child: const Text('문의 목록으로'),
    ),
  ];
}

/// 학생 이름 · 접수 시각 · 현재 처리 단계(FR-004). 학부모 정보는 넣지 않는다(FR-019).
/// 단계가 "접수"면 "… 접수 · 접수"로 반복되므로 단계를 붙이지 않는다(E2E 2026-10-27).
class _HeaderLine extends StatelessWidget {
  const _HeaderLine(this.summary);

  final TeacherInquirySummary summary;

  @override
  Widget build(BuildContext context) {
    final stage = summary.displayStage == InquiryStage.received
        ? ''
        : ' · ${NoticeText.stage(summary.displayStage)}';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        '${summary.studentName} · ${formatDateTime(summary.submittedAt)} 접수$stage',
        style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _LogHint extends StatelessWidget {
  const _LogHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      NoticeText.contentViewWillLog,
      style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.background, required this.foreground});

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(text, style: AppTextStyles.label.copyWith(color: foreground)),
      ),
    );
  }
}
