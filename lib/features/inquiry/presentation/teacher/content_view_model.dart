import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import 'teacher_inquiries_view_model.dart';

/// 원문 열람 화면 데이터. 원문은 화면이 열려 있는 동안 메모리에만 있다(원칙 III).
class ContentView {
  const ContentView({required this.detail, required this.content});

  final TeacherInquiryDetail detail;
  final String content;
}

/// F3-6 원문 열람. 원문 호출마다 서버에 감사 기록이 남으므로 화면당 한 번만 부른다
/// (specs/003 research R6, 긴급 상세와 같은 규칙). 상세만 실패해 "다시 시도"하면 원문은 다시
/// 부르지 않는다. 화면을 새로 열면 새 열람이므로 이전 원문을 쓰지 않는다(FR-016).
class ContentViewModel extends AsyncNotifier<ContentView> {
  ContentViewModel(this.inquiryId);

  final String inquiryId;

  /// 받은 원문. 다시 시도(같은 Notifier 의 재빌드)에서도 유지된다.
  String? _content;

  @override
  Future<ContentView> build() async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    var content = _content;
    if (content == null) {
      content = _content = await repo.content(inquiryId);
      // "원문 확인 필요" 문의는 첫 열람에 "교사 확인"이 되므로 목록·홈을 새로 고친다.
      Future.microtask(() {
        if (ref.mounted) {
          ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
        }
      });
    }
    final detail = await repo.detail(inquiryId);
    return ContentView(detail: detail, content: content);
  }
}

final contentViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<ContentViewModel, ContentView, String>(ContentViewModel.new);
