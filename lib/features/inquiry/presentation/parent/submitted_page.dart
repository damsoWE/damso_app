import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/form_layout.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../format.dart';
import 'urgent_notice_view.dart';

/// 안내 화면에 넘기는 값. 경로의 extra 로만 전달한다(URL 에 넣지 않음).
class SubmittedArgs {
  const SubmittedArgs({
    required this.outcome,
    required this.studentName,
    required this.submittedAt,
    this.threadRootId,
  });

  final SubmitOutcome outcome;
  final String studentName;
  final DateTime submittedAt;

  /// 재문의 접수일 때 스레드 루트 ID. 있으면 "보낸 문의 보기"가 그 스레드로 간다(specs/007 R5).
  final String? threadRootId;
}

/// 보낸 뒤 안내: F2-5 접수(Figma 216-5227) · F2-5a 응답 가능 시간 안내(216-5258)
/// · F2-3 계열 긴급 전달. 작성 화면을 교체해 열리므로 뒤로 가면 탭 화면으로 간다(FR-013).
class SubmittedPage extends StatelessWidget {
  const SubmittedPage({super.key, required this.args});

  final SubmittedArgs args;

  @override
  Widget build(BuildContext context) {
    final outcome = args.outcome;
    final (body, button) = switch (outcome) {
      UrgentNotice(:final hotlines) => (
        UrgentNoticeView(hotlines: hotlines),
        '보낸 문의 보기',
      ),
      DeferredNotice() => (
        _NoticeBody(
          headline: NoticeText.of(Notice.deferred),
          caption: '문의는 접수되었어요. 다시 작성하지 않아도 돼요.',
          args: args,
        ),
        '문의 목록으로',
      ),
      ReceivedNotice() => (
        _NoticeBody(
          headline: NoticeText.of(Notice.received),
          caption: '진행 상황은 문의 탭에서 확인할 수 있어요.',
          args: args,
        ),
        '보낸 문의 보기',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('문의 접수')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [body],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SubmitButton(
                  label: button,
                  onPressed: () => _toInquiries(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on SubmittedPage {
  /// 재문의면 목록 위에 스레드를 올려(뒤로 → 목록), 처음 문의면 목록으로 간다.
  void _toInquiries(BuildContext context) {
    context.go('/parent/inquiries');
    final rootId = args.threadRootId;
    if (rootId != null) context.push('/parent/inquiries/$rootId/thread');
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({
    required this.headline,
    required this.caption,
    required this.args,
  });

  final String headline;
  final String caption;
  final SubmittedArgs args;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(headline, style: AppTextStyles.display),
        const SizedBox(height: AppSpacing.sm),
        Text(
          caption,
          style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          color: AppColors.bgSurface,
          child: ListTile(
            title: Text('${args.studentName} 학생 문의', style: AppTextStyles.subtitle),
            subtitle: Text('접수 시각 · ${formatDateTime(args.submittedAt)}'),
          ),
        ),
      ],
    );
  }
}
