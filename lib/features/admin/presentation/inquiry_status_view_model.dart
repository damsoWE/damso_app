import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/admin_repository_provider.dart';
import '../domain/models.dart';
import 'format.dart';

/// 학급 한 줄(specs/006 data-model §2). 학급 이름·담임 연결 여부는 학급 목록에서 가져온다.
class InquiryStatusRow {
  const InquiryStatusRow({required this.status, this.label, this.homeroomAssigned});

  final ClassroomInquiryStatus status;

  /// "3학년 2반". 학급 목록에 없거나 목록을 못 받았으면 null("학급"으로 보인다).
  final String? label;

  /// 모르면 null(담임 표시를 숨긴다).
  final bool? homeroomAssigned;
}

/// 화면 위 요약. 학급별 서버 값을 더한 것이고 다시 나누지 않는다(research R2).
class InquiryStatusTotals {
  const InquiryStatusTotals({
    required this.total,
    required this.waiting,
    required this.confirmed,
    required this.answered,
  });

  final int total;
  final int waiting;
  final int confirmed;
  final int answered;
}

class InquiryStatusState {
  const InquiryStatusState({required this.rows, required this.totals});

  /// 서버 현황 순서(학년·반 순).
  final List<InquiryStatusRow> rows;
  final InquiryStatusTotals totals;

  /// 학급은 있는데 문의가 하나도 없다("아직 접수된 문의가 없어요").
  bool get allZero => rows.isNotEmpty && totals.total == 0;
}

/// ADM-4 문의 현황(specs/006 research R4). 현황과 학급 목록을 함께 요청한다.
/// 현황이 실패하면 화면 전체 오류, 학급 목록만 실패하면 건수는 보이고 이름은 "학급".
class InquiryStatusViewModel extends AsyncNotifier<InquiryStatusState> {
  @override
  Future<InquiryStatusState> build() async {
    final repo = ref.watch(adminRepositoryProvider);
    final classrooms = _classroomsOrNull(repo.listClassrooms());
    final statuses = await repo.inquiryStatus();
    final byId = {
      for (final c in (await classrooms) ?? const <AdminClassroom>[]) c.classroomId: c,
    };
    final rows = [
      for (final s in statuses)
        InquiryStatusRow(
          status: s,
          label: switch (byId[s.classroomId]) {
            final c? => classroomLabel(c.grade, c.classNumber),
            null => null,
          },
          homeroomAssigned: byId[s.classroomId]?.homeroomAssigned,
        ),
    ];
    int sum(int Function(ClassroomInquiryStatus) pick) =>
        statuses.fold(0, (acc, s) => acc + pick(s));
    return InquiryStatusState(
      rows: rows,
      totals: InquiryStatusTotals(
        total: sum((s) => s.total),
        waiting: sum((s) => s.waiting),
        confirmed: sum((s) => s.confirmed),
        answered: sum((s) => s.answered),
      ),
    );
  }

  /// 학급 목록 실패는 화면을 막지 않는다. 현황 요청과 동시에 시작한다.
  static Future<List<AdminClassroom>?> _classroomsOrNull(
    Future<List<AdminClassroom>> request,
  ) async {
    try {
      return await request;
    } on AppException {
      return null;
    }
  }

  /// 탭 재진입·당겨서 새로 고침(FR-007).
  /// 실패는 상태(AsyncError)로 보이므로 여기서는 기다리기만 한다.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on AppException {
      // 화면이 오류 상태로 그린다.
    }
  }
}

final inquiryStatusViewModelProvider =
    AsyncNotifierProvider.autoDispose<InquiryStatusViewModel, InquiryStatusState>(
      InquiryStatusViewModel.new,
    );
