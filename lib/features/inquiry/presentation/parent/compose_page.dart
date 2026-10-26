import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../../core/widgets/form_layout.dart';
import '../../../../core/widgets/system_notice.dart';
import '../../../parent/domain/child.dart';
import '../../domain/notice_text.dart';
import 'compose_view_model.dart';
import 'submitted_page.dart';

/// F2-2 문의 작성 (Figma 216-5213). 제목 없이 본문만, 대상 자녀는 홈에서 고른 자녀다.
/// 본문은 화면이 열려 있는 동안 메모리에만 둔다(원칙 III, research R12).
class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({super.key, required this.child});

  final Child child;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final _content = TextEditingController();

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await ref
        .read(composeViewModelProvider(widget.child).notifier)
        .submit(_content.text);
    if (result == null || !mounted) return;
    // 작성 화면을 안내 화면으로 바꿔, 뒤로 가기로 같은 내용을 다시 보내지 않게 한다(FR-013).
    context.pushReplacement(
      '/parent/inquiries/submitted',
      extra: SubmittedArgs(
        outcome: result.outcome,
        studentName: widget.child.studentName,
        submittedAt: result.submittedAt,
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
    final provider = composeViewModelProvider(widget.child);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    final child = widget.child;
    final teacher = child.teacher?.displayName;

    return PopScope(
      canPop: _content.text.trim().isEmpty || state.isSubmitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('문의 작성')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Card(
                      color: AppColors.bgSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${child.studentName} · ${child.classroom.grade}학년 ${child.classroom.classNumber}반',
                              style: AppTextStyles.subtitle,
                            ),
                            if (teacher != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '받는 분 · $teacher 선생님',
                                style: AppTextStyles.small.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('문의 내용', style: AppTextStyles.smallStrong),
                    const SizedBox(height: AppSpacing.sm),
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
                        hintText: '있었던 일과 바라는 점을 편하게 적어 주세요.',
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
                      const MessageText('문의 내용은 2,000자까지 쓸 수 있어요.'),
                    const SizedBox(height: AppSpacing.md),
                    const SystemNotice(NoticeText.composeGuide),
                    MessageText(state.errorMessage),
                    if (state.showTimeoutHint)
                      const Text(NoticeText.timeoutHint, style: AppTextStyles.small),
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
                    label: '문의 보내기',
                    isLoading: state.isSubmitting,
                    onPressed: state.canSubmit ? _submit : null,
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
