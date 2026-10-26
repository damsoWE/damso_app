import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import 'teacher_inquiries_view_model.dart';

/// 긴급 문의 상세 + 원문. 원문은 화면이 열려 있는 동안 메모리에만 있다(원칙 III).
class UrgentDetail {
  const UrgentDetail({required this.detail, required this.content});

  final TeacherInquiryDetail detail;
  final String content;
}

/// F3-5. 원문 호출은 서버에 열람 기록을 남기고 "교사 확인"으로 바꾸므로, 화면이 살아 있는 동안
/// 한 번만 부른다(research R8). 상세만 실패해 "다시 시도"하면 원문은 다시 부르지 않는다.
/// Repository 는 watch 하지 않아 다시 그려져도 build 가 돌지 않는다.
class UrgentDetailViewModel extends AsyncNotifier<UrgentDetail> {
  UrgentDetailViewModel(this.inquiryId);

  final String inquiryId;

  /// 받은 원문. 다시 시도(같은 Notifier 의 재빌드)에서도 유지된다.
  String? _content;

  @override
  Future<UrgentDetail> build() async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    var content = _content;
    if (content == null) {
      // 원문을 먼저 연다 — 첫 열람으로 바뀐 "교사 확인" 단계가 상세 타임라인에 함께 보이도록.
      content = _content = await repo.content(inquiryId);
      // 단계가 바뀌었으므로 상세 조회 성공 여부와 관계없이 목록·홈을 새로 고친다.
      Future.microtask(() {
        if (ref.mounted) {
          ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
        }
      });
    }
    final detail = await repo.detail(inquiryId);
    return UrgentDetail(detail: detail, content: content);
  }
}

final urgentDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<UrgentDetailViewModel, UrgentDetail, String>(
      UrgentDetailViewModel.new,
    );
