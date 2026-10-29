import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';

/// 교사 문의 목록(data-model §3 TeacherInquiriesState). 교사 홈은 거르지 않은 목록,
/// 문의 탭은 칸마다 서버가 거른 목록을 쓴다(api-v0.11 `answerStatus`).
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

  /// 서버 `totalElements`(칸 목록이면 거른 결과 기준).
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
/// [tab]이 없으면 거르지 않은 목록(교사 홈)이고, 이 목록을 새로 고치면 열려 있는 칸 목록도
/// 함께 새로 고친다 — 답변 전송·알림 등 목록을 새로 고치는 곳은 이 한 곳만 부르면 된다.
class TeacherInquiriesViewModel extends AsyncNotifier<TeacherInquiriesState> {
  TeacherInquiriesViewModel([this.tab]);

  final InquiryTab? tab;

  /// 목록이 바뀔 때마다 올린다. 시작할 때와 값이 다르면 늦게 끝난 응답을 버린다
  /// (새로 고침과 다음 페이지가 겹쳐도 새 목록이 옛 목록에 덮이지 않게).
  int _generation = 0;
  int _refreshSeq = 0;

  Future<TeacherInquiryPage> _list({int page = 0}) => ref
      .read(teacherInquiryRepositoryProvider)
      .list(page: page, answerStatus: tab?.answerStatus);

  @override
  Future<TeacherInquiriesState> build() async =>
      TeacherInquiriesState.fromPage(await _list());

  /// 0페이지부터 다시. 받는 동안 보던 목록은 그대로 둔다.
  Future<void> refresh() async {
    if (tab == null) {
      for (final t in InquiryTab.values) {
        final provider = teacherInquiryTabViewModelProvider(t);
        if (ref.exists(provider)) unawaited(ref.read(provider.notifier).refresh());
      }
    }
    if (!state.hasValue) {
      ref.invalidateSelf();
      return;
    }
    final seq = ++_refreshSeq;
    _generation++; // 진행 중인 다음 페이지 응답은 버린다
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다(해제된 ref 사용 방지).
    try {
      final page = await _list();
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
      final page = await _list(page: next);
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

/// 문의 탭 위 두 칸(Figma `SegmentTabs` 351-1866). 칸마다 서버가 거른다(api-v0.11).
enum InquiryTab {
  waiting(AnswerStatus.waiting),
  answered(AnswerStatus.answered);

  const InquiryTab(this.answerStatus);

  final AnswerStatus answerStatus;
}

/// 지금 고른 칸. 처음에는 답변 대기(specs/004 FR-028).
class InquiryTabController extends Notifier<InquiryTab> {
  @override
  InquiryTab build() => InquiryTab.waiting;

  void select(InquiryTab tab) => state = tab;
}

final inquiryTabProvider = NotifierProvider.autoDispose<InquiryTabController, InquiryTab>(
  InquiryTabController.new,
);

/// 거르지 않은 목록(교사 홈).
final teacherInquiriesViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      TeacherInquiriesViewModel,
      TeacherInquiriesState
    >(TeacherInquiriesViewModel.new);

/// 문의 탭의 칸별 목록. 칸 옆 개수는 각 목록의 [TeacherInquiriesState.total]이다.
final teacherInquiryTabViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<TeacherInquiriesViewModel, TeacherInquiriesState, InquiryTab>(
      TeacherInquiriesViewModel.new,
    );
