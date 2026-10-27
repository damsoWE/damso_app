import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 일반 문의 상세(본문 없음). 원문은 부르지 않는다 — 열람 기록이 남기 때문이다(FR-024).
class PendingDetailViewModel extends AsyncNotifier<TeacherInquiryDetail> {
  PendingDetailViewModel(this.inquiryId);

  final String inquiryId;

  @override
  Future<TeacherInquiryDetail> build() =>
      ref.watch(teacherInquiryRepositoryProvider).detail(inquiryId);
}

final pendingDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<PendingDetailViewModel, TeacherInquiryDetail, String>(
      PendingDetailViewModel.new,
    );
