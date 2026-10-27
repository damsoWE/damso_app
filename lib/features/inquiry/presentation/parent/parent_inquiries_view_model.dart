import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 학부모가 보낸 문의 목록(F2-4, 홈 문의 영역). 최신순은 서버가 정한다.
/// 다시 불러오기: 화면을 열 때 · 탭으로 돌아올 때 · 당겨서 새로 고칠 때 · 보낸 직후(research R6).
class ParentInquiriesViewModel extends AsyncNotifier<List<ParentInquirySummary>> {
  @override
  Future<List<ParentInquirySummary>> build() =>
      ref.watch(parentInquiryRepositoryProvider).list();

  Future<void> refresh() async {
    ref.invalidate(parentInquiryDetailsProvider);
    ref.invalidateSelf();
    await future.catchError((_) => const <ParentInquirySummary>[]);
  }
}

final parentInquiriesViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      ParentInquiriesViewModel,
      List<ParentInquirySummary>
    >(ParentInquiriesViewModel.new);

/// 펼친 카드의 상세(타임라인·안내 코드). 화면이 살아 있는 동안 한 번만 부른다(research R6).
class ParentInquiryDetails
    extends Notifier<Map<String, AsyncValue<ParentInquiryDetail>>> {
  @override
  Map<String, AsyncValue<ParentInquiryDetail>> build() => const {};

  Future<void> load(String inquiryId) async {
    final current = state[inquiryId];
    if (current != null && !current.hasError) return;
    state = {...state, inquiryId: const AsyncLoading()};
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      final detail = await ref
          .read(parentInquiryRepositoryProvider)
          .detail(inquiryId);
      state = {...state, inquiryId: AsyncData(detail)};
    } on AppException catch (e, st) {
      state = {...state, inquiryId: AsyncError(e, st)};
    } finally {
      link.close();
    }
  }
}

final parentInquiryDetailsProvider = NotifierProvider.autoDispose<
  ParentInquiryDetails,
  Map<String, AsyncValue<ParentInquiryDetail>>
>(ParentInquiryDetails.new);
