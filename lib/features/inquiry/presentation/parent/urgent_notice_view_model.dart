import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 긴급 카드에서 다시 여는 긴급 안내(FR-018). 상세 응답의 안내·번호 코드로 화면을 고른다.
class UrgentNoticeViewModel extends AsyncNotifier<ParentInquiryDetail> {
  UrgentNoticeViewModel(this.inquiryId);

  final String inquiryId;

  @override
  Future<ParentInquiryDetail> build() =>
      ref.watch(parentInquiryRepositoryProvider).detail(inquiryId);
}

final urgentNoticeViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<UrgentNoticeViewModel, ParentInquiryDetail, String>(
      UrgentNoticeViewModel.new,
    );
