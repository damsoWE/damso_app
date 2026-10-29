import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../inquiry/data/inquiry_repository_providers.dart';
import '../../inquiry/domain/models.dart';
import '../../inquiry/domain/teacher_inquiry_repository.dart';
// 기능 간 참조는 이 한 곳(답변 카드의 표시 이름, research R5).
import '../../teacher/data/teacher_repository_provider.dart';

/// 스레드 카드 하나(specs/004 data-model §4).
sealed class ThreadEntry {
  const ThreadEntry(this.at);

  /// 정렬 기준 시각.
  final DateTime at;
}

/// 학부모 문의 카드(최초 문의 또는 재문의).
final class ParentCard extends ThreadEntry {
  const ParentCard({
    required this.inquiryId,
    required this.isFollowUp,
    required this.urgent,
    required DateTime submittedAt,
    this.requests,
    this.unanswered = false,
    this.followUp,
  }) : super(submittedAt);

  final String inquiryId;
  final bool isFollowUp;
  final bool urgent;

  /// 정리된 요청사항. 없으면 null(정리 전·원문 확인 필요·긴급).
  final String? requests;

  /// 마지막 답변보다 늦게 받은 재문의(research R4).
  final bool unanswered;
  final TeacherFollowUp? followUp;
}

/// 교사 답변 카드.
final class AnswerCard extends ThreadEntry {
  const AnswerCard({required this.content, required DateTime sentAt}) : super(sentAt);

  final String content;
}

class ThreadState {
  const ThreadState({
    required this.detail,
    required this.entries,
    this.teacherName,
  });

  final TeacherInquiryDetail detail;

  /// 시간순.
  final List<ThreadEntry> entries;

  /// 답변 카드의 "<표시 이름> 선생님". 모르면 null.
  final String? teacherName;

  String get title => detail.summary.title;
  String get studentName => detail.summary.studentName;
}

/// F4-3 스레드(research R5). 원문은 부르지 않는다(spec FR-015a).
/// 상세와 교사 프로필(답변 카드의 표시 이름)을 함께 요청하고, 상세를 받은 뒤
/// 루트(정리됨)와 긴급이 아닌 재문의의 번역본을 함께 요청해 요청사항을 채운다.
class ThreadViewModel extends AsyncNotifier<ThreadState> {
  ThreadViewModel(this.inquiryId);

  /// 스레드 루트 ID.
  final String inquiryId;

  @override
  Future<ThreadState> build() async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    final teacherName = _teacherName();
    final detail = await repo.detail(inquiryId);
    final summary = detail.summary;
    final requests = await Future.wait([
      !summary.urgent && summary.refinementStatus == RefinementStatus.refined
          ? _requests(repo, inquiryId)
          : Future.value(null),
      for (final f in detail.followUps)
        f.urgent ? Future.value(null) : _requests(repo, f.inquiryId),
    ]);
    return ThreadState(
      detail: detail,
      entries: _entries(detail, requests),
      teacherName: await teacherName,
    );
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(build);
  }

  /// 표시 이름을 못 받아도 스레드는 연다("선생님"으로 보인다).
  Future<String?> _teacherName() async {
    try {
      return (await ref.read(teacherRepositoryProvider).getProfile()).displayName;
    } on AppException {
      return null;
    }
  }

  /// 번역본의 요청사항. 아직 정리되지 않았거나(409) 비어 있으면 null.
  static Future<String?> _requests(TeacherInquiryRepository repo, String id) async {
    try {
      final requests = (await repo.refinement(id)).requests;
      return requests.isEmpty ? null : requests;
    } on AppException catch (e) {
      if (e.code == ErrorCodes.refinementNotReady) return null;
      rethrow;
    }
  }

  /// [requests]: 0번은 루트, 그 뒤는 재문의 순서대로.
  static List<ThreadEntry> _entries(TeacherInquiryDetail detail, List<String?> requests) {
    final lastAnswerAt = detail.answers.isEmpty ? null : detail.answers.last.sentAt;
    final entries = <ThreadEntry>[
      ParentCard(
        inquiryId: detail.summary.inquiryId,
        isFollowUp: false,
        urgent: detail.summary.urgent,
        submittedAt: detail.summary.submittedAt,
        requests: requests.first,
      ),
      for (final a in detail.answers) AnswerCard(content: a.content, sentAt: a.sentAt),
      for (final (i, f) in detail.followUps.indexed)
        ParentCard(
          inquiryId: f.inquiryId,
          isFollowUp: true,
          urgent: f.urgent,
          submittedAt: f.submittedAt,
          requests: requests[i + 1],
          unanswered: lastAnswerAt == null || f.submittedAt.isAfter(lastAnswerAt),
          followUp: f,
        ),
    ];
    // 최초 문의는 언제나 맨 앞, 나머지는 시간순.
    final rest = entries.sublist(1)..sort((a, b) => a.at.compareTo(b.at));
    return [entries.first, ...rest];
  }
}

final threadViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<ThreadViewModel, ThreadState, String>(ThreadViewModel.new);
