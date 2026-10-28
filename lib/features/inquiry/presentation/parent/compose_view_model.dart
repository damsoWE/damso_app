import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/util/uuid.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../../parent/domain/child.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import 'parent_inquiries_view_model.dart';

/// 본문 상한(코드 포인트, research R4).
const inquiryMaxLength = 2000;

/// 앞뒤 공백을 뺀 코드 포인트 수(서버와 같은 방식).
int inquiryLength(String content) => content.trim().runes.length;

/// F2-2 문의 작성 상태(data-model §2 ComposeState). 본문은 TextEditingController 에만 있다.
class ComposeState {
  const ComposeState({
    this.length = 0,
    this.isSubmitting = false,
    this.errorMessage,
    this.showTimeoutHint = false,
    this.cooldown = Cooldown.none,
  });

  final int length;
  final bool isSubmitting;
  final String? errorMessage;

  /// 응답 없이 끝난 실패 — "보낸 문의 목록에서 먼저 확인" 안내를 함께 보인다(research R3).
  final bool showTimeoutHint;
  final Cooldown cooldown;

  bool get tooLong => length > inquiryMaxLength;

  /// 1분 제한 중에도 버튼은 막지 않는다. 긴급 문의는 제한을 받지 않으므로(US2-6, 원칙 IV)
  /// 판단은 서버에 맡기고, 앱은 남은 시간만 보여 준다.
  bool get canSubmit => length >= 1 && !tooLong && !isSubmitting;

  ComposeState copyWith({
    int? length,
    bool? isSubmitting,
    String? Function()? errorMessage,
    bool? showTimeoutHint,
    Cooldown? cooldown,
  }) => ComposeState(
    length: length ?? this.length,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    showTimeoutHint: showTimeoutHint ?? this.showTimeoutHint,
    cooldown: cooldown ?? this.cooldown,
  );
}

/// 문의 작성·보내기. 결과 안내 화면 고르기는 [InquirySubmitted.outcome].
class ComposeViewModel extends Notifier<ComposeState> {
  ComposeViewModel(this.child);

  final Child child;
  final _timer = CooldownTimer();

  /// (자녀, 다듬은 본문) 한 쌍의 제출 키. 같은 쌍을 다시 보내면 같은 키를 쓴다(research R3).
  String? _key;
  String? _keyContent;

  @override
  ComposeState build() {
    ref.onDispose(_timer.cancel);
    return const ComposeState();
  }

  void onChanged(String content) {
    final length = inquiryLength(content);
    if (length != state.length) state = state.copyWith(length: length);
  }

  /// 성공하면 결과, 실패하면 null(쓴 내용은 화면에 그대로 남는다).
  Future<InquirySubmitted?> submit(String content) async {
    final trimmed = content.trim();
    onChanged(content);
    if (!state.canSubmit) return null;
    if (_keyContent != trimmed) {
      _key = uuidV4();
      _keyContent = trimmed;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: () => null,
      showTimeoutHint: false,
    );
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      final result = await ref
          .read(parentInquiryRepositoryProvider)
          .submit(
            studentId: child.studentId,
            content: trimmed,
            idempotencyKey: _key!,
          );
      _key = null;
      _keyContent = null;
      ref.invalidate(parentInquiriesViewModelProvider);
      state = state.copyWith(isSubmitting: false);
      return result;
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.message,
        showTimeoutHint: e.isNetworkError,
      );
      _timer.startIfLimited(e, (c) => state = state.copyWith(cooldown: c));
      return null;
    } finally {
      link.close();
    }
  }
}

final composeViewModelProvider = NotifierProvider.autoDispose
    .family<ComposeViewModel, ComposeState, Child>(ComposeViewModel.new);

/// 홈에서 고른 자녀로 작성을 시작할 수 있는지(FR-003). 안 되면 안내 문구.
String? composeBlockedReason(Child child) =>
    child.teacher == null ? NoticeText.noHomeroomTeacher : null;
