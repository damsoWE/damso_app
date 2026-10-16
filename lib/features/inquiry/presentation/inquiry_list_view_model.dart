import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inquiry_repository_provider.dart';
import '../domain/inquiry_repository.dart';

/// 문의 목록 ViewModel. 상태는 로딩 / 목록 / 오류.
class InquiryListViewModel extends AsyncNotifier<List<Inquiry>> {
  @override
  Future<List<Inquiry>> build() => ref.read(inquiryRepositoryProvider).list();

  /// 당겨서 새로고침 등에서 호출한다.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(inquiryRepositoryProvider).list(),
    );
  }
}

final inquiryListViewModelProvider =
    AsyncNotifierProvider<InquiryListViewModel, List<Inquiry>>(
      InquiryListViewModel.new,
    );
