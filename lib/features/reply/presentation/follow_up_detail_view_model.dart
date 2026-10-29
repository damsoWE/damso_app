import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../../inquiry/data/inquiry_repository_providers.dart';
import '../../inquiry/domain/models.dart';

/// 재문의 상세에 보일 내용(specs/004 data-model §6).
sealed class FollowUpDetail {
  const FollowUpDetail();
}

/// 번역본 있음 → F3-2 와 같은 사실관계·요청사항·정서강도.
final class Refined extends FollowUpDetail {
  const Refined(this.refinement);

  final InquiryRefinement refinement;
}

/// 409 `REFINEMENT_NOT_READY` — 아직 정리되지 않았다.
final class NotRefined extends FollowUpDetail {
  const NotRefined();
}

/// 긴급 재문의. 번역본을 요청하지 않는다.
final class Urgent extends FollowUpDetail {
  const Urgent();
}

/// F4-3b 재문의 상세(research R13). 원문은 부르지 않는다 — "원문 보기"를 누를 때만 연다.
/// family 키는 재문의 ID와 긴급 여부(긴급이면 번역본을 요청하지 않으므로 처음부터 알아야 한다).
class FollowUpDetailViewModel extends AsyncNotifier<FollowUpDetail> {
  FollowUpDetailViewModel(this.key);

  final ({String followUpId, bool urgent}) key;

  @override
  Future<FollowUpDetail> build() async {
    if (key.urgent) return const Urgent();
    try {
      return Refined(
        await ref.read(teacherInquiryRepositoryProvider).refinement(key.followUpId),
      );
    } on AppException catch (e) {
      if (e.code == ErrorCodes.refinementNotReady) return const NotRefined();
      rethrow;
    }
  }
}

final followUpDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<FollowUpDetailViewModel, FollowUpDetail, ({String followUpId, bool urgent})>(
      FollowUpDetailViewModel.new,
    );
