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

  /// 문의 탭의 한 칸에 보일 문의(specs/004 FR-029). 불러온 페이지 안에서 나눈다(FR-031).
  List<TeacherInquirySummary> itemsOf(InquiryTab tab) => [
    for (final i in items)
      if (i.needsAnswer == (tab == InquiryTab.waiting)) i,
  ];

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

  /// [before] 뒤에 페이지를 붙인다. 페이지 사이에 새 문의가 들어와 경계가 밀리면
  /// 같은 문의가 다시 올 수 있으므로 ID 로 거른다.
  static TeacherInquiriesState fromPage(
    TeacherInquiryPage page, {
    List<TeacherInquirySummary> before = const [],
  }) {
    final seen = {for (final i in before) i.inquiryId};
    return TeacherInquiriesState(
      items: [...before, ...page.items.where((i) => seen.add(i.inquiryId))],
      total: page.totalElements,
      nextPage: page.hasMore ? page.page + 1 : null,
    );
  }
}

/// 다시 불러오기 계기: 열 때 · 탭으로 돌아올 때 · 당겨서 새로 고칠 때 · 열린 상태 알림 수신 ·
/// 앱이 다시 앞으로 올 때(research R7). 일정 간격 조회는 하지 않는다.
class TeacherInquiriesViewModel extends AsyncNotifier<TeacherInquiriesState> {
  /// 목록이 바뀔 때마다 올린다. 시작할 때와 값이 다르면 늦게 끝난 응답을 버린다
  /// (새로 고침과 다음 페이지가 겹쳐도 새 목록이 옛 목록에 덮이지 않게).
  int _generation = 0;
  int _refreshSeq = 0;

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
    final seq = ++_refreshSeq;
    _generation++; // 진행 중인 다음 페이지 응답은 버린다
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      final page = await ref.read(teacherInquiryRepositoryProvider).list();
      if (seq != _refreshSeq) return; // 더 나중에 시작한 새로 고침이 있다
      _generation++;
      state = AsyncData(TeacherInquiriesState.fromPage(page));
    } on AppException catch (e) {
      final current = state.value;
      if (seq == _refreshSeq && current != null) {
        // 버려진 다음 페이지 요청이 남긴 로딩 표시도 함께 내린다.
        state = AsyncData(
          current.copyWith(refreshError: () => e.message, isLoadingMore: false),
        );
      }
    } finally {
      link.close();
    }
  }

  /// 다음 페이지. 실패한 뒤에는 자동으로 다시 부르지 않고 "다시 시도"([retry])로만 부른다.
  Future<void> loadMore({bool retry = false}) async {
    final current = state.value;
    final next = current?.nextPage;
    if (current == null || next == null || current.isLoadingMore) return;
    if (current.loadMoreError != null && !retry) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    final link = ref.keepAlive();
    try {
      final page = await ref.read(teacherInquiryRepositoryProvider).list(page: next);
      if (generation != _generation) return; // 그사이 새로 고침으로 목록이 바뀌었다
      state = AsyncData(
        TeacherInquiriesState.fromPage(page, before: current.items),
      );
    } on AppException catch (e) {
      if (generation != _generation) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: () => e.message),
      );
    } finally {
      link.close();
    }
  }
}

/// 문의 탭 위 두 칸(Figma `SegmentTabs` 351-1866).
enum InquiryTab { waiting, answered }

/// 지금 고른 칸. 처음에는 답변 대기(specs/004 FR-028).
class InquiryTabController extends Notifier<InquiryTab> {
  @override
  InquiryTab build() => InquiryTab.waiting;

  void select(InquiryTab tab) => state = tab;
}

final inquiryTabProvider = NotifierProvider.autoDispose<InquiryTabController, InquiryTab>(
  InquiryTabController.new,
);

final teacherInquiriesViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      TeacherInquiriesViewModel,
      TeacherInquiriesState
    >(TeacherInquiriesViewModel.new);
