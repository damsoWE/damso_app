import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import 'teacher_inquiries_view_model.dart';

/// F3-6 원문 열람. 원문 호출마다 서버에 감사 기록이 남으므로 화면당 한 번만 부른다
/// (specs/003 research R6). Repository 를 watch 하지 않아 다시 그려져도 build 가 돌지 않고,
/// "다시 시도"(실패 뒤 invalidate)와 화면을 새로 열 때만 다시 부른다(FR-016).
/// 머리 줄(제목·학생·접수 시각)은 상세 화면이 넘겨준 요약으로 그려 상세를 다시 요청하지 않는다 —
/// 그 요청이 실패해 이미 열람한 원문이 오류 화면이 되는 일을 막는다(코드 리뷰 반영).
/// 원문은 화면이 열려 있는 동안 메모리에만 있다(원칙 III).
class ContentViewModel extends AsyncNotifier<String> {
  ContentViewModel(this.inquiryId);

  final String inquiryId;

  @override
  Future<String> build() async {
    final content = await ref.read(teacherInquiryRepositoryProvider).content(inquiryId);
    // "원문 확인 필요" 문의는 첫 열람에 "교사 확인"이 되므로 목록·홈을 새로 고친다.
    Future.microtask(() {
      if (ref.mounted) {
        ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
      }
    });
    return content;
  }
}

final contentViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<ContentViewModel, String, String>(ContentViewModel.new);
