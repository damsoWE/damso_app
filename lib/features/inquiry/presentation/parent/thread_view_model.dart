import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 학부모 문의 스레드(F4-1). 상세 응답 하나로 처음 문의·답변·재문의를 모두 그린다(specs/007 R3).
/// 다시 불러오기: 다시 시도 · 당겨서 새로 고침 · 답변 알림을 받았을 때(FR-019).
class ParentThreadViewModel extends AsyncNotifier<ParentInquiryDetail> {
  ParentThreadViewModel(this.inquiryId);

  final String inquiryId;

  @override
  Future<ParentInquiryDetail> build() =>
      ref.watch(parentInquiryRepositoryProvider).detail(inquiryId);

  /// 당겨서 새로 고침. 실패해도 예외를 던지지 않고 오류 상태로 둔다.
  Future<void> reload() async {
    ref.invalidateSelf();
    await future.then<void>((_) {}, onError: (_) {});
  }
}

final parentThreadViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<ParentThreadViewModel, ParentInquiryDetail, String>(
      ParentThreadViewModel.new,
    );
