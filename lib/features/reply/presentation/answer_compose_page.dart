import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_tag.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/system_notice.dart';
import '../../inquiry/domain/models.dart';
import '../../inquiry/presentation/format.dart';
import '../domain/answer_text.dart';
import '../domain/models.dart';
import 'answer_compose_view_model.dart';
import 'suggestion_card.dart';

/// F4-2a~F4-2h 답변 작성 · 점검 · 전송 (Figma 216-5381 · 216-5548 · 216-5397 · 216-5411 ·
/// 216-5439 · 216-5467 · 216-5481 · 216-5493 · 216-5505 · 216-5520).
/// 학부모의 이름·이메일·연락처는 없다(spec FR-024). 본문·점검 결과는 일반 Text 로만 그린다(FR-025).
class AnswerComposePage extends ConsumerStatefulWidget {
  const AnswerComposePage({super.key, required this.target});

  final AnswerTarget target;

  @override
  ConsumerState<AnswerComposePage> createState() => _AnswerComposePageState();
}

class _AnswerComposePageState extends ConsumerState<AnswerComposePage> {
  final _controller = TextEditingController();

  /// 확인 대화상자에서 "나가기"를 고른 뒤에만 true.
  bool _leaving = false;

  AnswerTarget get _target => widget.target;

  @override
  void initState() {
    super.initState();
    ref
        .read(answerComposeViewModelProvider(_target.inquiryId).notifier)
        .seenFollowUp(_target.lastSeenFollowUpId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = answerComposeViewModelProvider(_target.inquiryId);
    final s = ref.watch(provider);
    final vm = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final sent = next.sent;
      if (sent != null && previous?.sent == null) {
        _afterSent(context, sent);
        return;
      }
      final message = next.message;
      if (message != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        vm.clearMessage();
      }
      final expired = next.sessionExpiredNotice;
      if (expired != null) {
        // 루트 ScaffoldMessenger 라 로그인 화면으로 옮겨도 보인다(research R15).
        messenger.showSnackBar(SnackBar(content: Text(expired)));
        vm.clearSessionNotice();
      }
    });

    // ViewModel 본문(바꾸기·되돌리기로 바뀐 것 포함)을 입력칸과 맞춘다.
    if (_controller.text != s.text) {
      _controller.value = TextEditingValue(
        text: s.text,
        selection: TextSelection.collapsed(offset: s.text.length),
      );
    }

    return PopScope(
      canPop: _leaving || !s.hasText || s.sent != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave == true && context.mounted) {
          setState(() => _leaving = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_title(s.step))),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: _body(s, vm),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _actions(s, vm),
          ),
        ),
      ),
    );
  }

  String _title(ComposeStep step) => switch (step) {
    Editing() => AnswerText.composeTitle,
    Reviewing() || ReviewFailed() => AnswerText.reviewingTitle,
    Reviewed() => AnswerText.resultTitle,
    EditedAfterReview() => AnswerText.editTitle,
    Sending() || SendFailed() || NewFollowUpArrived() => AnswerText.sendingTitle,
  };

  /// 전송 성공. 스레드에서 왔으면 [AnswerSent] 를 돌려주며 닫고, 거쳐 온 화면(재문의 상세·원문)도
  /// 같은 값을 받으면 차례로 닫아 스레드로 돌아간다(스레드가 두 겹이 되지 않게).
  /// 아니면 이 화면을 스레드로 바꾼다(research R14).
  void _afterSent(BuildContext context, AnswerSent sent) {
    if (_target.fromThread) {
      context.pop(sent);
      return;
    }
    context.pushReplacement('/teacher/inquiries/${_target.inquiryId}/thread');
  }

  Future<bool?> _confirmDiscard(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: const Text(AnswerText.discardConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AnswerText.discardCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(AnswerText.discardLeave),
        ),
      ],
    ),
  );

  // ───────── 본문 ─────────

  List<Widget> _body(ComposeState s, AnswerComposeViewModel vm) => switch (s.step) {
    Editing() => [
      _RecipientCard(_target),
      ..._requests(),
      const SizedBox(height: AppSpacing.lg),
      _Label(s.hasText ? AnswerText.writtenLabel : AnswerText.answerLabel),
      _input(s, vm),
      const SizedBox(height: AppSpacing.ms),
      _Hint(AnswerText.notSentHint),
    ],
    Reviewing() => [
      _RecipientCard(_target),
      const SizedBox(height: AppSpacing.lg),
      const _Label(AnswerText.writtenLabel),
      _ReadOnlyText(s.text),
      const SizedBox(height: AppSpacing.ms),
      const _Hint(AnswerText.reviewingGuide),
      const SizedBox(height: AppSpacing.md),
      const SystemNotice(AnswerText.reviewingNotice, icon: Icons.hourglass_top),
    ],
    Reviewed(:final review, :final applied) => review.highlights.isEmpty
        ? [
            const _Badge(AnswerText.noSuggestionBadge, tone: TagTone.success),
            const SizedBox(height: AppSpacing.ms),
            const _Label(AnswerText.writtenLabel),
            _ReadOnlyText(s.text),
            const SizedBox(height: AppSpacing.md),
            const SystemNotice(AnswerText.noSuggestion, icon: Icons.check_circle_outline),
          ]
        : [
            _Badge(
              applied.isEmpty
                  ? AnswerText.suggestionCount(review.highlights.length)
                  : AnswerText.appliedCount(applied.length),
              tone: applied.isEmpty ? TagTone.warning : TagTone.success,
            ),
            const SizedBox(height: AppSpacing.ms),
            const _Label(AnswerText.writtenLabel),
            _ReadOnlyText(s.text),
            for (var i = 0; i < review.highlights.length; i++) ...[
              const SizedBox(height: AppSpacing.md),
              SuggestionCard(
                index: i,
                highlight: review.highlights[i],
                applied: applied.containsKey(i),
                canApply: vm.canApply(i),
                onApply: () => vm.apply(i),
                onUndo: () => vm.undo(i),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _Hint(applied.isEmpty ? AnswerText.resultHint : AnswerText.appliedHint),
          ],
    ReviewFailed() => [
      const _Label(AnswerText.writtenLabel),
      _ReadOnlyText(s.text),
      const SizedBox(height: AppSpacing.md),
      const SystemNotice(AnswerText.reviewFailed, icon: Icons.warning_amber_outlined),
      const SizedBox(height: AppSpacing.ms),
      const _Hint(AnswerText.reviewFailedGuide),
    ],
    EditedAfterReview() => [
      ..._requests(),
      const SizedBox(height: AppSpacing.lg),
      const _Label(AnswerText.editedLabel),
      _input(s, vm),
      const SizedBox(height: AppSpacing.md),
      const SystemNotice(AnswerText.editedNotice, icon: Icons.edit_outlined),
    ],
    Sending() => [
      const Text(AnswerText.sendingHeading, style: AppTextStyles.display),
      const SizedBox(height: AppSpacing.xs),
      const _Hint(AnswerText.sendingGuide),
      const SizedBox(height: AppSpacing.lg),
      const _Label(AnswerText.recipientLabel),
      Text(
        AnswerText.recipientLine(_target.studentName, _target.title),
        style: AppTextStyles.body,
      ),
      const SizedBox(height: AppSpacing.md),
      const _Label(AnswerText.writtenLabel),
      _ReadOnlyText(s.text),
      const SizedBox(height: AppSpacing.md),
      const SystemNotice(AnswerText.sendOnceNotice, icon: Icons.info_outline),
    ],
    SendFailed(:final maybeSent) => [
      const Text(AnswerText.sendFailedHeading, style: AppTextStyles.display),
      const SizedBox(height: AppSpacing.xs),
      const _Hint(AnswerText.sendFailedGuide),
      const SizedBox(height: AppSpacing.lg),
      const _Label(AnswerText.unsentLabel),
      _ReadOnlyText(s.text),
      const SizedBox(height: AppSpacing.md),
      const SystemNotice(AnswerText.sendFailedHint, icon: Icons.wifi_off),
      if (maybeSent) ...[
        const SizedBox(height: AppSpacing.sm),
        const SystemNotice(AnswerText.maybeSentHint, icon: Icons.info_outline),
      ],
    ],
    NewFollowUpArrived(:final followUps, :final notice) => [
      const Text(AnswerText.newFollowUpHeading, style: AppTextStyles.display),
      const SizedBox(height: AppSpacing.xs),
      const _Hint(AnswerText.newFollowUpGuide),
      const SizedBox(height: AppSpacing.md),
      SystemNotice(notice, icon: Icons.mark_chat_unread_outlined),
      if (followUps.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        const _Label(AnswerText.newFollowUpLabel),
        for (final f in followUps) ...[
          _NewFollowUpCard(target: _target, followUp: f),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
      const SizedBox(height: AppSpacing.md),
      const _Label(AnswerText.unsentLabel),
      _ReadOnlyText(s.text),
    ],
  };

  List<Widget> _requests() {
    final requests = _target.requests;
    if (requests == null || requests.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AnswerText.requestsLabel, style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              requests,
              style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _input(ComposeState s, AnswerComposeViewModel vm) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _controller,
        onChanged: vm.updateText,
        minLines: 6,
        maxLines: 12,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: AnswerText.placeholder,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      if (s.inputError != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            s.inputError!,
            style: AppTextStyles.small.copyWith(color: AppColors.statusUrgentText),
          ),
        ),
    ],
  );

  // ───────── 하단 버튼 ─────────

  Widget _actions(ComposeState s, AnswerComposeViewModel vm) => switch (s.step) {
    Editing() => FilledButton(
      onPressed: s.canReview ? vm.review : null,
      child: const Text(AnswerText.reviewButton),
    ),
    Reviewing() => const FilledButton(
      onPressed: null,
      child: Text(AnswerText.reviewingButton),
    ),
    Reviewed() => _pair(
      OutlinedButton(onPressed: vm.startEdit, child: const Text(AnswerText.editButton)),
      FilledButton(
        onPressed: s.canSend ? vm.send : null,
        child: const Text(AnswerText.sendButton),
      ),
    ),
    // F4-2f·F4-2d: 전송은 위(보조), 다시 점검은 아래(주 버튼)로 쌓는다(Figma 216-5493·216-5467).
    ReviewFailed() => _stacked(
      OutlinedButton(
        onPressed: s.canSend ? vm.send : null,
        child: const Text(AnswerText.sendAfterCheckButton),
      ),
      FilledButton(
        onPressed: s.canReview ? vm.review : null,
        child: const Text(AnswerText.recheckButton),
      ),
    ),
    EditedAfterReview() => _stacked(
      OutlinedButton(
        onPressed: s.canSend ? vm.send : null,
        child: const Text(AnswerText.sendEditedButton),
      ),
      FilledButton(
        onPressed: s.canReview ? vm.review : null,
        child: const Text(AnswerText.recheckButton),
      ),
    ),
    Sending() => const FilledButton(
      onPressed: null,
      child: Text(AnswerText.sendingButton),
    ),
    SendFailed(:final canResend) => _pair(
      OutlinedButton(onPressed: vm.startEdit, child: const Text(AnswerText.editButton)),
      canResend
          ? FilledButton(onPressed: vm.resend, child: const Text(AnswerText.resendButton))
          : null,
    ),
    NewFollowUpArrived() => _pair(
      OutlinedButton(onPressed: vm.startEdit, child: const Text(AnswerText.editButton)),
      FilledButton(
        onPressed: s.canSend ? vm.resend : null,
        child: const Text(AnswerText.resendButton),
      ),
    ),
  };

  Widget _stacked(Widget top, Widget bottom) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [top, const SizedBox(height: AppSpacing.sm), bottom],
  );

  Widget _pair(Widget left, Widget? right) => Row(
    children: [
      Expanded(child: left),
      if (right != null) ...[
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    ],
  );
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard(this.target);

  final AnswerTarget target;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      border: Border.all(color: AppColors.borderDefault),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AnswerText.recipient(target.studentName), style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          target.title,
          style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

/// 쓰는 동안 온 재문의. 누르면 재문의 상세(F4-3b)를 열고, 돌아오면 쓰던 답변을 그대로 보낸다
/// — 그래서 재문의 상세에서는 "답변 작성"을 숨긴다.
class _NewFollowUpCard extends StatelessWidget {
  const _NewFollowUpCard({required this.target, required this.followUp});

  final AnswerTarget target;
  final TeacherFollowUp followUp;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgSurface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.borderDefault),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.push(
        '/teacher/inquiries/${target.inquiryId}/follow-ups/${followUp.inquiryId}',
        extra: FollowUpArgs(
          rootId: target.inquiryId,
          studentName: target.studentName,
          rootTitle: target.title,
          followUp: followUp,
          lastSeenFollowUpId: null,
          canAnswer: false,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AnswerText.parentCardTitle(target.studentName, followUp: true),
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AnswerText.newFollowUpHint(formatDateTime(followUp.submittedAt)),
              style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: AppTextStyles.bodyStrong),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
  );
}

/// 점검 중·결과·전송 화면의 본문. 고칠 수 없고 일반 Text 로만 그린다.
class _ReadOnlyText extends StatelessWidget {
  const _ReadOnlyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      border: Border.all(color: AppColors.borderInput),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(text, style: AppTextStyles.body),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.tone});

  final String text;
  final TagTone tone;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerLeft, child: AppTag(text, tone: tone));
}
