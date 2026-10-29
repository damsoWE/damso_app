import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../inquiry/data/inquiry_repository_providers.dart';
import '../../inquiry/domain/models.dart';
import '../../inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import '../data/answer_repository_provider.dart';
import '../domain/answer_text.dart';
import '../domain/models.dart';

/// 답변 작성 화면이 지금 보일 단계(specs/004 data-model §3, research R6).
sealed class ComposeStep {
  const ComposeStep();
}

/// F4-2a(빈칸)·F4-2a-2(입력). 바로 전송할 수 없다(Clarifications Q1).
final class Editing extends ComposeStep {
  const Editing();
}

/// F4-2b. 본문은 잠긴다.
final class Reviewing extends ComposeStep {
  const Reviewing();
}

/// F4-2c(제안 있음)·F4-2c-1(적용 후)·F4-2e(제안 없음).
/// [applied]: 제안 번호 → (원래 문장, 바꾼 문장). "바꾸기"·"되돌리기"는 결과를 무효로 만들지 않는다(FR-007).
final class Reviewed extends ComposeStep {
  const Reviewed(this.review, {this.applied = const {}});

  final AnswerReview review;
  final Map<int, ({String original, String replaced})> applied;
}

/// F4-2f. 점검 불가·점검 요청 오류. 본문은 그대로이고 전송할 수 있다(FR-008).
final class ReviewFailed extends ComposeStep {
  const ReviewFailed();
}

/// F4-2d. 점검 뒤 입력칸에서 직접 고쳤다. 이전 결과는 보이지 않는다(FR-007).
final class EditedAfterReview extends ComposeStep {
  const EditedAfterReview();
}

/// F4-2g.
final class Sending extends ComposeStep {
  const Sending();
}

/// 쓰는 동안 새 재문의가 와서 서버가 전송을 막았다(409 `NEW_FOLLOW_UP`, api-v0.11).
/// 답변은 저장되지 않았고 본문은 그대로다. [followUps]는 교사가 아직 못 본 재문의(시간순),
/// [notice]는 서버 문구. 다시 보내면 새 재문의까지 본 것으로 보낸다.
final class NewFollowUpArrived extends ComposeStep {
  const NewFollowUpArrived(this.followUps, {required this.notice});

  final List<TeacherFollowUp> followUps;
  final String notice;
}

/// F4-2h. [canResend] 가 false 면 다시 보내기를 숨긴다(이미 종료된 문의 등).
/// [maybeSent]: 응답 없이 끊겨 이미 저장됐을 수 있다(멱등키 없음, research R8).
final class SendFailed extends ComposeStep {
  const SendFailed({required this.canResend, this.maybeSent = false});

  final bool canResend;
  final bool maybeSent;
}

class ComposeState {
  const ComposeState({
    this.step = const Editing(),
    this.text = '',
    this.reviewRequested = false,
    this.inputError,
    this.message,
    this.sent,
    this.sessionExpiredNotice,
  });

  final ComposeStep step;

  /// 지금 본문. 화면이 열려 있는 동안 메모리에만 있다(FR-003, 원칙 III·VI).
  final String text;

  /// 이 화면에서 점검을 요청한 적이 있는지. 전송 `reviewed` 로 보낸다(FR-014).
  final bool reviewRequested;

  /// 입력칸 아래에 보일 서버 입력 오류.
  final String? inputError;

  /// 한 번 보일 안내(스낵바). 화면이 보인 뒤 [AnswerComposeViewModel.clearMessage].
  final String? message;

  /// 전송 성공. 화면이 스레드로 옮긴다.
  final AnswerSent? sent;

  /// 세션이 만료돼 작성 중 본문을 잃었다는 안내(research R15).
  final String? sessionExpiredNotice;

  bool get hasText => text.trim().isNotEmpty;

  bool get canReview =>
      hasText && (step is Editing || step is EditedAfterReview || step is ReviewFailed);

  /// 입력 직후(Editing)에는 전송할 수 없다. 점검을 한 번 거친 뒤부터 전송할 수 있다(FR-004).
  bool get canSend => hasText && switch (step) {
    Reviewed() || ReviewFailed() || EditedAfterReview() || NewFollowUpArrived() => true,
    SendFailed(:final canResend) => canResend,
    _ => false,
  };

  ComposeState copyWith({
    ComposeStep? step,
    String? text,
    bool? reviewRequested,
    String? Function()? inputError,
    String? Function()? message,
    AnswerSent? Function()? sent,
    String? Function()? sessionExpiredNotice,
  }) => ComposeState(
    step: step ?? this.step,
    text: text ?? this.text,
    reviewRequested: reviewRequested ?? this.reviewRequested,
    inputError: inputError != null ? inputError() : this.inputError,
    message: message != null ? message() : this.message,
    sent: sent != null ? sent() : this.sent,
    sessionExpiredNotice: sessionExpiredNotice != null
        ? sessionExpiredNotice()
        : this.sessionExpiredNotice,
  );
}

/// F4-2a~F4-2h 답변 작성 · 점검 · 전송(specs/004 research R6~R9·R14·R15).
/// family 키는 스레드 루트 ID 문자열이다 — 다시 그려도 같은 ViewModel 이 본문을 지킨다(analyze U1).
/// 점검 결과를 자동으로 반영하거나 자동으로 전송하는 코드는 두지 않는다(원칙 V).
class AnswerComposeViewModel extends Notifier<ComposeState> {
  AnswerComposeViewModel(this.inquiryId);

  final String inquiryId;

  /// 교사가 본 마지막 재문의 ID. 화면 상태가 아니라 전송에만 쓴다.
  String? _lastSeenFollowUpId;
  bool _seenSet = false;

  /// 작성 화면이 처음 열릴 때 들어오기 전 화면의 값을 한 번만 넣는다(다시 그려도 바뀌지 않는다).
  /// 상태를 바꾸지 않으므로 initState 에서 불러도 된다.
  void seenFollowUp(String? followUpId) {
    if (_seenSet) return;
    _seenSet = true;
    _lastSeenFollowUpId = followUpId;
  }

  @override
  ComposeState build() {
    ref.listen(sessionControllerProvider, (_, next) {
      if (next is SignedOut && next.sessionExpired && state.hasText) {
        state = state.copyWith(
          sessionExpiredNotice: () => AnswerText.sessionExpiredDraftLost,
        );
      }
    });
    return const ComposeState();
  }

  void updateText(String text) {
    if (text == state.text) return;
    final step = state.step;
    if (step is Reviewing || step is Sending) return; // 잠겨 있다
    state = state.copyWith(
      text: text,
      inputError: () => null,
      // 점검 뒤 직접 고치면 결과는 무효(F4-2d).
      step: step is Editing ? step : const EditedAfterReview(),
    );
  }

  /// "답변 수정" — 결과·실패 화면에서 입력칸으로.
  void startEdit() {
    final step = state.step;
    if (step is Reviewed ||
        step is ReviewFailed ||
        step is SendFailed ||
        step is NewFollowUpArrived) {
      state = state.copyWith(step: const EditedAfterReview());
    }
  }

  Future<void> review() async {
    if (!state.canReview) return;
    final before = state.step;
    state = state.copyWith(
      step: const Reviewing(),
      reviewRequested: true,
      inputError: () => null,
    );
    final link = ref.keepAlive(); // 요청 중 화면을 떠나도 응답 처리를 마친다.
    try {
      final result = await ref.read(answerRepositoryProvider).review(inquiryId, state.text);
      if (!ref.mounted) return;
      state = state.copyWith(
        step: result.available ? Reviewed(result) : const ReviewFailed(),
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      if (e.code == ErrorCodes.invalidInput) {
        state = state.copyWith(
          step: before is Editing ? before : const EditedAfterReview(),
          inputError: () => e.fieldErrors['content'] ?? e.message,
        );
      } else {
        // 점검 장애는 전송을 막지 않는다 — 실패 화면으로(FR-008).
        state = state.copyWith(
          step: const ReviewFailed(),
          message: e.isNetworkError ? null : () => e.message,
        );
      }
    } finally {
      link.close();
    }
  }

  /// "직접 전송" 류. 교사가 누를 때만 부른다(FR-010).
  Future<void> send() async {
    if (!state.canSend) return;
    state = state.copyWith(step: const Sending(), inputError: () => null);
    final link = ref.keepAlive();
    try {
      final sent = await ref.read(answerRepositoryProvider).send(
        inquiryId,
        state.text.trim(),
        reviewed: state.reviewRequested,
        lastSeenFollowUpId: _lastSeenFollowUpId,
      );
      if (!ref.mounted) return;
      state = state.copyWith(sent: () => sent);
      // 보낸 문의는 답변 완료로 옮겨 가므로 목록·홈을 새로 고친다(specs/004 FR-029).
      ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
    } on AppException catch (e) {
      if (!ref.mounted) return;
      if (e.code == ErrorCodes.invalidInput) {
        state = state.copyWith(
          step: const EditedAfterReview(),
          inputError: () => e.fieldErrors['content'] ?? e.message,
        );
      } else if (e.code == ErrorCodes.threadClosed) {
        state = state.copyWith(
          step: const SendFailed(canResend: false),
          message: () => e.message,
        );
      } else if (e.code == ErrorCodes.newFollowUp) {
        await _showNewFollowUps(e.message);
      } else {
        state = state.copyWith(
          step: SendFailed(canResend: true, maybeSent: e.isNetworkError),
          message: e.isNetworkError ? null : () => e.message,
        );
      }
    } finally {
      link.close();
    }
  }

  /// 409 `NEW_FOLLOW_UP` 뒤: 상세를 다시 받아 못 본 재문의를 보이고, 다음 전송은 그 마지막 재문의까지
  /// 본 것으로 보낸다. 자동으로 다시 보내지 않는다(원칙 V). 상세를 못 받으면 전송 실패로 두고,
  /// 다시 보내면 서버가 또 막으므로 그때 다시 받는다.
  Future<void> _showNewFollowUps(String notice) async {
    try {
      final detail = await ref.read(teacherInquiryRepositoryProvider).detail(inquiryId);
      if (!ref.mounted) return;
      final all = detail.followUps;
      final seen = _lastSeenFollowUpId;
      final start = seen == null ? 0 : all.indexWhere((f) => f.inquiryId == seen) + 1;
      _lastSeenFollowUpId = all.lastOrNull?.inquiryId;
      state = state.copyWith(step: NewFollowUpArrived(all.sublist(start), notice: notice));
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        step: SendFailed(canResend: true, maybeSent: false),
        message: () => e.isNetworkError ? notice : e.message,
      );
    }
  }

  Future<void> resend() => send();

  bool canApply(int index) {
    final step = state.step;
    if (step is! Reviewed || index >= step.review.highlights.length) return false;
    if (step.applied.containsKey(index)) return false;
    return state.text.contains(step.review.highlights[index].excerpt);
  }

  /// "바꾸기" — 그 표현 한 곳만 제안으로 바꾼다(FR-006).
  void apply(int index) {
    if (!canApply(index)) return;
    final step = state.step as Reviewed;
    final h = step.review.highlights[index];
    state = state.copyWith(
      text: state.text.replaceFirst(h.excerpt, h.suggestion),
      step: Reviewed(
        step.review,
        applied: {...step.applied, index: (original: h.excerpt, replaced: h.suggestion)},
      ),
    );
  }

  /// "되돌리기".
  void undo(int index) {
    final step = state.step;
    if (step is! Reviewed) return;
    final record = step.applied[index];
    if (record == null) return;
    state = state.copyWith(
      text: state.text.replaceFirst(record.replaced, record.original),
      step: Reviewed(step.review, applied: {...step.applied}..remove(index)),
    );
  }

  void clearMessage() => state = state.copyWith(message: () => null);

  void clearSessionNotice() =>
      state = state.copyWith(sessionExpiredNotice: () => null);
}

final answerComposeViewModelProvider = NotifierProvider.autoDispose
    .family<AnswerComposeViewModel, ComposeState, String>(
      AnswerComposeViewModel.new,
    );
