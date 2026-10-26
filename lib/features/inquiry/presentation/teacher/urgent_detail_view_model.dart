import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 긴급 문의 상세 + 원문. 원문은 화면이 열려 있는 동안 메모리에만 있다(원칙 III).
class UrgentDetail {
  const UrgentDetail({required this.detail, required this.content});

  final TeacherInquiryDetail detail;
  final String content;
}

/// F3-5. 원문 호출은 서버에 열람 기록을 남기고 "교사 확인"으로 바꾸므로, 화면이 살아 있는 동안
/// 한 번만 부른다(research R8). Repository 는 watch 하지 않아 다시 그려져도 build 가 돌지 않는다.
class UrgentDetailViewModel extends AsyncNotifier<UrgentDetail> {
  UrgentDetailViewModel(this.inquiryId);

  final String inquiryId;

  @override
  Future<UrgentDetail> build() async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    // 원문을 먼저 연다 — 첫 열람으로 바뀐 "교사 확인" 단계가 상세 타임라인에 함께 보이도록.
    final content = await repo.content(inquiryId);
    final detail = await repo.detail(inquiryId);
    return UrgentDetail(detail: detail, content: content);
  }
}

final urgentDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<UrgentDetailViewModel, UrgentDetail, String>(
      UrgentDetailViewModel.new,
    );
