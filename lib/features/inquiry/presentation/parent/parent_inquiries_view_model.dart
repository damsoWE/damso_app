import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 학부모가 보낸 문의 목록(F2-4, 홈 문의 영역). 최신순은 서버가 정한다.
/// 다시 불러오기: 화면을 열 때 · 탭으로 돌아올 때 · 당겨서 새로 고칠 때 · 보낸 직후(research R6).
class ParentInquiriesViewModel extends AsyncNotifier<List<ParentInquirySummary>> {
  @override
  Future<List<ParentInquirySummary>> build() =>
      ref.watch(parentInquiryRepositoryProvider).list();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future.catchError((_) => const <ParentInquirySummary>[]);
  }
}

final parentInquiriesViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      ParentInquiriesViewModel,
      List<ParentInquirySummary>
    >(ParentInquiriesViewModel.new);
