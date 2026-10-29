import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/form_layout.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../domain/notice_text.dart';
import 'follow_up_view_model.dart';
import 'submitted_page.dart';

/// 이어서 묻기 화면에 넘기는 값. 경로의 extra 로만 전달한다(URL 에 넣지 않음).
class ParentFollowUpArgs {
  const ParentFollowUpArgs({required this.studentName});

  final String studentName;
}

/// F4-1a 이어서 묻기 (Figma 225-1722). 같은 스레드에 재문의를 보낸다.
/// 본문은 화면이 열려 있는 동안 메모리에만 둔다(원칙 III).
class FollowUpPage extends ConsumerStatefulWidget {
  const FollowUpPage({super.key, required this.inquiryId, required this.args});

  final String inquiryId;
  final ParentFollowUpArgs args;

  @override
  ConsumerState<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends ConsumerState<FollowUpPage> {
  final _content = TextEditingController();

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final result = await ref
        .read(followUpViewModelProvider(widget.inquiryId).notifier)
        .send(_content.text);
    if (result == null || !mounted) return;
    // 입력 화면을 안내 화면으로 바꿔, 뒤로 가기로 같은 내용을 다시 보내지 않게 한다.
    context.pushReplacement(
      '/parent/inquiries/submitted',
      extra: SubmittedArgs(
        outcome: result.outcome,
        studentName: widget.args.studentName,
        submittedAt: result.submittedAt,
        threadRootId: result.threadRootId,
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(NoticeText.discardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 쓰기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = followUpViewModelProvider(widget.inquiryId);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);

    return PopScope(
      // 보내는 중에는 떠나지 않게 한다 — 긴급 안내(109·112)를 반드시 보여 줘야 한다.
      canPop: _content.text.trim().isEmpty && !state.sending,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || state.sending) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('이어서 묻기')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      '${widget.args.studentName} · 같은 문의에 이어서 물어요',
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _content,
                      minLines: 8,
                      maxLines: 14,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onChanged: (text) {
                        vm.onChanged(text);
                        setState(() {}); // PopScope 의 canPop 갱신
                      },
                      decoration: const InputDecoration(
                        hintText: '더 궁금한 점이나 바라는 점을 적어 주세요.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${state.length} / 2,000자',
                      style: AppTextStyles.micro.copyWith(
                        color: state.tooLong
                            ? AppColors.statusUrgentText
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (state.tooLong)
                      const MessageText('내용은 2,000자까지 쓸 수 있어요.'),
                    const SizedBox(height: AppSpacing.md),
                    const SystemNotice(NoticeText.composeGuide),
                    MessageText(state.errorMessage),
                    CooldownNotice(state.cooldown),
                  ],
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
                    label: '보내기',
                    isLoading: state.sending,
                    onPressed: state.canSend ? _send : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
