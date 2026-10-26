import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 교사 문의 목록(data-model §3 TeacherInquiriesState). 교사 홈과 문의 탭이 함께 쓴다.
class TeacherInquiriesState {
  const TeacherInquiriesState({
    required this.items,
    required this.total,
    this.nextPage,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.refreshError,
  });

  final List<TeacherInquirySummary> items;
  final int total;

  /// 다음에 부를 페이지. null 이면 끝.
  final int? nextPage;
  final bool isLoadingMore;

  /// 다음 페이지만 실패했을 때(목록 아래 "다시 시도").
  final String? loadMoreError;

  /// 새로 고침이 실패했을 때. 보던 목록은 그대로 둔다.
  final String? refreshError;

  Iterable<TeacherInquirySummary> get unconfirmedUrgent =>
      items.where((i) => i.isUnconfirmedUrgent);

  TeacherInquiriesState copyWith({
    bool? isLoadingMore,
    String? Function()? loadMoreError,
    String? Function()? refreshError,
  }) => TeacherInquiriesState(
    items: items,
    total: total,
    nextPage: nextPage,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
    refreshError: refreshError != null ? refreshError() : this.refreshError,
  );

  static TeacherInquiriesState fromPage(
    TeacherInquiryPage page, {
    List<TeacherInquirySummary> before = const [],
  }) => TeacherInquiriesState(
    items: [...before, ...page.items],
    total: page.totalElements,
    nextPage: page.hasMore ? page.page + 1 : null,
  );
}

/// 다시 불러오기 계기: 열 때 · 탭으로 돌아올 때 · 당겨서 새로 고칠 때 · 열린 상태 알림 수신 ·
/// 앱이 다시 앞으로 올 때(research R7). 일정 간격 조회는 하지 않는다.
class TeacherInquiriesViewModel extends AsyncNotifier<TeacherInquiriesState> {
  @override
  Future<TeacherInquiriesState> build() async => TeacherInquiriesState.fromPage(
    await ref.read(teacherInquiryRepositoryProvider).list(),
  );

  /// 0페이지부터 다시. 받는 동안 보던 목록은 그대로 둔다.
  Future<void> refresh() async {
    if (!state.hasValue) {
      ref.invalidateSelf();
      return;
    }
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      final page = await ref.read(teacherInquiryRepositoryProvider).list();
      state = AsyncData(TeacherInquiriesState.fromPage(page));
    } on AppException catch (e) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(refreshError: () => e.message));
      }
    } finally {
      link.close();
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    final next = current?.nextPage;
    if (current == null || next == null || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    final link = ref.keepAlive();
    try {
      final page = await ref.read(teacherInquiryRepositoryProvider).list(page: next);
      state = AsyncData(
        TeacherInquiriesState.fromPage(page, before: current.items),
      );
    } on AppException catch (e) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: () => e.message),
      );
    } finally {
      link.close();
    }
  }
}

final teacherInquiriesViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      TeacherInquiriesViewModel,
      TeacherInquiriesState
    >(TeacherInquiriesViewModel.new);
