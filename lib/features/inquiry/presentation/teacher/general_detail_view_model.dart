import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/error_codes.dart';
import '../../data/inquiry_repository_providers.dart';
import '../../domain/models.dart';
import 'teacher_inquiries_view_model.dart';

/// 일반 문의 상세가 보일 화면(specs/003 research R2). 서버 정리 상태로 고른다.
sealed class GeneralDetail {
  const GeneralDetail(this.detail);

  final TeacherInquiryDetail detail;
}

/// F3-2 정리본. 번역본은 화면이 열려 있는 동안 메모리에만 있다(원칙 III).
final class Refined extends GeneralDetail {
  const Refined(super.detail, this.refinement);

  final InquiryRefinement refinement;
}

/// F3-3 원문 확인 필요. 다시 정리하기 버튼은 [TeacherInquiryDetail.retryAvailable] 로 정한다.
final class NeedsOriginal extends GeneralDetail {
  const NeedsOriginal(super.detail);
}

/// 정리 중. [afterRetry] 면 이 화면에서 다시 정리하기를 받아들인 경우(F3-3a).
/// API 가 둘을 구분해 주지 않아, 화면을 다시 열면 정리 중으로 보인다(research R2).
final class Refining extends GeneralDetail {
  const Refining(super.detail, {required this.afterRetry});

  final bool afterRetry;
}

/// 긴급 문의였다(잘못된 주소·경쟁). 화면이 긴급 상세(F3-5)로 바꾼다.
final class UrgentRedirect extends GeneralDetail {
  const UrgentRedirect(super.detail);
}

class GeneralDetailState {
  const GeneralDetailState({
    required this.view,
    this.isRetrying = false,
    this.isRechecking = false,
    this.message,
  });

  final GeneralDetail view;

  /// 다시 정리하기 요청 중(버튼을 다시 누를 수 없다, FR-011).
  final bool isRetrying;

  /// 다시 확인 중. 보던 화면은 그대로 둔다(FR-012).
  final bool isRechecking;

  /// 스낵바로 한 번 보일 서버 안내. 화면이 보인 뒤 [GeneralDetailViewModel.clearMessage].
  final String? message;

  GeneralDetailState copyWith({
    bool? isRetrying,
    bool? isRechecking,
    String? Function()? message,
  }) => GeneralDetailState(
    view: view,
    isRetrying: isRetrying ?? this.isRetrying,
    isRechecking: isRechecking ?? this.isRechecking,
    message: message != null ? message() : this.message,
  );
}

/// 일반 문의 상세(F3-2 · F3-3 · F3-3a · 정리 중). 상세를 먼저 읽어 화면을 고르고(FR-003),
/// 정리 완료일 때만 번역본을 부른다(원칙 IV — 정리 결과는 검증된 것만).
/// 일정 간격 조회는 하지 않는다. 상태 확인은 [recheck](다시 확인·당겨서 새로 고침)뿐이다.
class GeneralDetailViewModel extends AsyncNotifier<GeneralDetailState> {
  GeneralDetailViewModel(this.inquiryId);

  final String inquiryId;

  /// 이 화면에서 다시 정리하기를 받아들였는지(정리 중 → F3-3a 로 보인다).
  bool _afterRetry = false;

  @override
  Future<GeneralDetailState> build() => _load();

  /// 상세 → (정리 완료면) 번역본. 번역본이 아직 없다는 409 면 상세를 한 번만 다시 읽는다(research R3).
  Future<GeneralDetailState> _load() async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    var detail = await repo.detail(inquiryId);
    if (detail.summary.urgent ||
        detail.summary.refinementStatus != RefinementStatus.refined) {
      return GeneralDetailState(view: _choose(detail));
    }
    try {
      return GeneralDetailState(view: await _refined(detail));
    } on AppException catch (e) {
      if (e.code != ErrorCodes.refinementNotReady) rethrow;
      detail = await repo.detail(inquiryId);
      final view = detail.summary.refinementStatus == RefinementStatus.refined
          ? await _refined(detail) // 또 409 면 오류로 둔다(무한 반복 없음)
          : _choose(detail);
      return GeneralDetailState(view: view, message: e.message);
    }
  }

  /// 번역본 첫 열람은 "교사 확인"을 만든다(FR-009). 단계가 바뀌었으므로 다음 상세 조회의
  /// 성공 여부와 관계없이 목록·홈 새로 고침을 먼저 예약하고, 머리 줄 단계가 맞도록 상세를 다시 읽는다.
  Future<Refined> _refined(TeacherInquiryDetail detail) async {
    final repo = ref.read(teacherInquiryRepositoryProvider);
    final refinement = await repo.refinement(inquiryId);
    if (detail.summary.stage == InquiryStage.refined) {
      Future.microtask(() {
        if (ref.mounted) {
          ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
        }
      });
      detail = await repo.detail(inquiryId);
    }
    return Refined(detail, refinement);
  }

  /// 긴급 여부는 `urgent` 로만 판단한다. 정리 상태가 비어 있다는 이유로 긴급 상세로 보내면
  /// 그 화면이 원문을 바로 열어 열람 기록이 남는다(원칙 III, 코드 리뷰 반영).
  GeneralDetail _choose(TeacherInquiryDetail detail) {
    if (detail.summary.urgent) return UrgentRedirect(detail);
    return switch (detail.summary.refinementStatus) {
      // 일반 문의인데 정리 상태가 없다 — 서버 응답이 계약과 다르다. 화면을 고르지 않고 오류로 둔다.
      null => throw const AppException(message: AppException.fallbackMessage),
      RefinementStatus.needsOriginal => NeedsOriginal(detail),
      // 정리 완료는 _load 가 먼저 처리하므로 여기서는 정리 중뿐이다.
      RefinementStatus.pending ||
      RefinementStatus.refined => Refining(detail, afterRetry: _afterRetry),
    };
  }

  /// 다시 확인·당겨서 새로 고침·원문 화면에서 돌아올 때. 받는 동안 보던 화면은 그대로 둔다.
  Future<void> recheck() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    if (current.isRechecking || current.isRetrying) return;
    state = AsyncData(current.copyWith(isRechecking: true));
    final link = ref.keepAlive(); // 요청 중에 화면을 떠나도 응답 처리를 마친다
    try {
      state = AsyncData(await _load());
    } on AppException catch (e) {
      state = AsyncData(current.copyWith(isRechecking: false, message: () => e.message));
    } finally {
      link.close();
    }
  }

  /// 다시 정리하기(1건당 1회, research R4). 판단은 서버가 하고 앱은 한 번만 눌리게 한다.
  Future<void> retry() async {
    final current = state.value;
    final view = current?.view;
    if (current == null || current.isRetrying || current.isRechecking) return;
    if (view is! NeedsOriginal || !view.detail.retryAvailable) return;
    state = AsyncData(current.copyWith(isRetrying: true));
    final link = ref.keepAlive();
    try {
      final status = await ref
          .read(teacherInquiryRepositoryProvider)
          .retryRefinement(inquiryId);
      // 여기부터는 서버가 받아들였다 — 1회를 썼으므로 다시 정리하기 버튼으로 돌아가지 않는다.
      _afterRetry = true;
      final retrying = GeneralDetailState(
        view: Refining(view.detail, afterRetry: true),
      );
      if (status == RefinementStatus.pending) {
        state = AsyncData(retrying);
        return;
      }
      try {
        state = AsyncData(await _load()); // 이미 끝났다
      } on AppException catch (e) {
        // 결과를 읽지 못했다. 다시 확인으로 확인하게 한다(코드 리뷰 반영).
        state = AsyncData(retrying.copyWith(message: () => e.message));
      }
    } on AppException catch (e) {
      if (e.code == ErrorCodes.refinementRetryUnavailable) {
        // 이미 썼거나 동시 요청 — 최신 상태를 따른다(버튼이 사라진다).
        try {
          state = AsyncData((await _load()).copyWith(message: () => e.message));
        } on AppException catch (_) {
          state = AsyncData(
            current.copyWith(isRetrying: false, message: () => e.message),
          );
        }
      } else {
        // 서버가 받아들이지 않았으므로 1회가 소모되지 않았다(US2-7).
        state = AsyncData(
          current.copyWith(isRetrying: false, message: () => e.message),
        );
      }
    } finally {
      link.close();
    }
  }

  void clearMessage() {
    final current = state.value;
    if (current?.message != null) {
      state = AsyncData(current!.copyWith(message: () => null));
    }
  }
}

final generalDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<GeneralDetailViewModel, GeneralDetailState, String>(
      GeneralDetailViewModel.new,
    );
