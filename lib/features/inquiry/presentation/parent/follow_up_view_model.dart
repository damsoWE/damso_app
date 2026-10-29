import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/util/uuid.dart';
import '../../../../core/widgets/cooldown.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import 'compose_view_model.dart';
import 'parent_inquiries_view_model.dart';

/// F4-1a 이어서 묻기 상태(specs/007 data-model §5). 본문은 TextEditingController 에만 있고
/// 여기에는 길이만 둔다(원칙 III·VI).
class FollowUpState {
  const FollowUpState({
    this.length = 0,
    this.sending = false,
    this.errorMessage,
    this.cooldown = Cooldown.none,
    this.done,
  });

  final int length;
  final bool sending;
  final String? errorMessage;

  /// 429 대기. 남은 시간 동안 보내기를 막는다(FR-013).
  final Cooldown cooldown;

  /// 접수 성공 결과. 화면이 접수 안내로 넘어가는 신호다.
  final FollowUpSubmitted? done;

  bool get tooLong => length > inquiryMaxLength;

  bool get canSend => length >= 1 && !tooLong && !sending && !cooldown.isActive;

  FollowUpState copyWith({
    int? length,
    bool? sending,
    String? Function()? errorMessage,
    Cooldown? cooldown,
    FollowUpSubmitted? done,
  }) => FollowUpState(
    length: length ?? this.length,
    sending: sending ?? this.sending,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    cooldown: cooldown ?? this.cooldown,
    done: done ?? this.done,
  );
}

/// 이어서 묻기. [inquiryId]는 스레드 루트 ID다.
class FollowUpViewModel extends Notifier<FollowUpState> {
  FollowUpViewModel(this.inquiryId);

  final String inquiryId;
  final _timer = CooldownTimer();

  /// (스레드, 다듬은 본문) 한 쌍의 제출 키. 같은 쌍을 다시 보내면 같은 키를 쓴다(research R4).
  String? _key;
  String? _keyContent;

  @override
  FollowUpState build() {
    ref.onDispose(_timer.cancel);
    return const FollowUpState();
  }

  void onChanged(String content) {
    final length = inquiryLength(content);
    if (length != state.length) state = state.copyWith(length: length);
  }

  /// 성공하면 결과, 실패하면 null(쓴 내용은 화면에 그대로 남는다).
  Future<FollowUpSubmitted?> send(String content) async {
    final trimmed = content.trim();
    onChanged(content);
    if (!state.canSend) return null;
    if (_keyContent != trimmed) {
      _key = uuidV4();
      _keyContent = trimmed;
    }
    state = state.copyWith(sending: true, errorMessage: () => null);
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다.
    try {
      final result = await ref
          .read(parentInquiryRepositoryProvider)
          .submitFollowUp(
            inquiryId: inquiryId,
            content: trimmed,
            idempotencyKey: _key!,
          );
      _key = null;
      _keyContent = null;
      ref.invalidate(parentInquiriesViewModelProvider);
      state = state.copyWith(sending: false, done: result);
      return result;
    } on AppException catch (e) {
      state = state.copyWith(sending: false, errorMessage: () => e.message);
      _timer.startIfLimited(e, (c) => state = state.copyWith(cooldown: c));
      return null;
    } finally {
      link.close();
    }
  }
}

final followUpViewModelProvider = NotifierProvider.autoDispose
    .family<FollowUpViewModel, FollowUpState, String>(FollowUpViewModel.new);
