import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import 'teacher_inquiries_view_model.dart';

/// 긴급 문의 상세 + 원문. 원문은 화면이 열려 있는 동안 메모리에만 있다(원칙 III).
class UrgentDetail {
  const UrgentDetail({required this.detail, required String this.content});

  /// 긴급이 아니었다. 원문은 열지 않았고, 화면은 일반 상세로 바꿔 간다.
  const UrgentDetail.notUrgent(this.detail) : content = null;

  final TeacherInquiryDetail detail;

  /// 열어 본 원문. 긴급이 아니라 원문을 열지 않았으면 null.
  final String? content;

  bool get redirectToGeneral => content == null;
}

/// F3-5. 원문 호출은 서버에 열람 기록을 남기고 "교사 확인"으로 바꾸므로, 화면이 살아 있는 동안
/// 한 번만 부른다(research R8). 원문을 받은 뒤 상세만 실패해 "다시 시도"하면 원문은 다시 부르지 않는다.
/// Repository 는 watch 하지 않아 다시 그려져도 build 가 돌지 않는다.
class UrgentDetailViewModel extends AsyncNotifier<UrgentDetail> {
  UrgentDetailViewModel(this.inquiryId);

  final String inquiryId;

  /// 받은 원문. 다시 시도(같은 Notifier 의 재빌드)에서도 유지된다.
  String? _content;

  @override
  Future<UrgentDetail> build() async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    // 상세를 먼저 읽는다. 라우트는 푸시 kind·목록 값으로 골라져 서버 현재 값과 다를 수 있고,
    // 원문 호출은 열람 기록을 남기고 단계를 바꾸므로 긴급이 확인된 뒤에만 연다(원칙 III).
    var detail = await repo.detail(inquiryId);
    if (!detail.summary.urgent) return UrgentDetail.notUrgent(detail);
    var content = _content;
    if (content == null) {
      // 원문을 연 뒤 상세를 다시 읽는다 — 첫 열람으로 바뀐 "교사 확인" 단계가 타임라인에 함께 보이도록.
      content = _content = await repo.content(inquiryId);
      // 단계가 바뀌었으므로 상세 조회 성공 여부와 관계없이 목록·홈을 새로 고친다.
      Future.microtask(() {
        if (ref.mounted) {
          ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
        }
      });
      detail = await repo.detail(inquiryId);
    }
    return UrgentDetail(detail: detail, content: content);
  }
}

final urgentDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<UrgentDetailViewModel, UrgentDetail, String>(
      UrgentDetailViewModel.new,
    );
