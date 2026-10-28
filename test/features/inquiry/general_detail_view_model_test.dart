import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/data/mock_teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/presentation/teacher/general_detail_view_model.dart';
import 'package:damso_app/features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';

TeacherInquiryDetail _detail({
  RefinementStatus? status = RefinementStatus.refined,
  InquiryStage stage = InquiryStage.refined,
  bool retryAvailable = false,
  bool? urgent,
}) => TeacherInquiryDetail(
  summary: TeacherInquirySummary(
    inquiryId: _id,
    studentId: 's',
    studentName: '김하나',
    urgent: urgent ?? status == null,
    title: '제목',
    stage: stage,
    refinementStatus: status,
    submittedAt: DateTime(2026, 10, 27),
    hasAnswer: false,
    lastAnsweredAt: null,
  ),
  timeline: const [],
  retryAvailable: retryAvailable,
);

final _refinement = InquiryRefinement(
  inquiryId: _id,
  title: '친구 관계 관련 문의',
  facts: '사실',
  requests: '요청',
  emotionLevel: EmotionLevel.high,
  emotionLabels: const [EmotionLabel.anger],
  refinedAt: DateTime(2026, 10, 27),
);

const _notReady = AppException(
  message: '아직 정리된 내용이 없습니다.',
  code: ErrorCodes.refinementNotReady,
  statusCode: 409,
);

/// 응답을 차례로 돌려주는 가짜 Repository(마지막 응답은 계속 쓴다).
class _ScriptedRepo implements TeacherInquiryRepository {
  _ScriptedRepo({required this.details, this.refinements = const []});

  List<TeacherInquiryDetail> details;
  List<Object> refinements; // InquiryRefinement 또는 AppException
  FutureOr<RefinementStatus> Function() retryResult = () => RefinementStatus.pending;
  Completer<void>? retryGate;
  Completer<void>? detailGate;

  /// 상세 n번째 호출(1부터)에서 던질 오류.
  final detailErrors = <int, AppException>{};

  int detailCalls = 0;
  int refinementCalls = 0;
  int retryCalls = 0;
  int listCalls = 0;

  T _next<T>(List<T> list, int n) => list[(n - 1).clamp(0, list.length - 1)];

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) async {
    detailCalls++;
    await detailGate?.future;
    final error = detailErrors[detailCalls];
    if (error != null) throw error;
    return _next(details, detailCalls);
  }

  @override
  Future<InquiryRefinement> refinement(String inquiryId) async {
    refinementCalls++;
    final r = refinements.isEmpty ? _refinement : _next(refinements, refinementCalls);
    if (r is AppException) throw r;
    return r as InquiryRefinement;
  }

  @override
  Future<RefinementStatus> retryRefinement(String inquiryId) async {
    retryCalls++;
    await retryGate?.future;
    return retryResult();
  }

  @override
  Future<TeacherInquiryPage> list({int page = 0, int size = 20}) async {
    listCalls++;
    return TeacherInquiryPage(items: const [], page: page, size: size, totalElements: 0);
  }

  @override
  Future<String> content(String inquiryId) => throw UnimplementedError();
}

void main() {
  final provider = generalDetailViewModelProvider(_id);

  ProviderContainer containerFor(TeacherInquiryRepository repo) {
    final c = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [teacherInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    c.listen(provider, (_, _) {});
    return c;
  }

  group('정리 완료', () {
    test('번역본을 한 번 불러와 Refined', () async {
      final repo = _ScriptedRepo(details: [_detail(stage: InquiryStage.teacherConfirmed)]);
      final c = containerFor(repo);
      final s = await c.read(provider.future);
      expect(s.view, isA<Refined>());
      expect((s.view as Refined).refinement.title, '친구 관계 관련 문의');
      expect(repo.refinementCalls, 1);
    });

    test('409 NOT_READY → 상세를 한 번 다시 읽어 원문 확인 필요로, 서버 안내를 남긴다', () async {
      final repo = _ScriptedRepo(
        details: [_detail(), _detail(status: RefinementStatus.needsOriginal, stage: InquiryStage.received)],
        refinements: [_notReady],
      );
      final c = containerFor(repo);
      final s = await c.read(provider.future);
      expect(s.view, isA<NeedsOriginal>());
      expect(s.message, '아직 정리된 내용이 없습니다.');
      expect(repo.detailCalls, 2);
      expect(repo.refinementCalls, 1);
    });

    test('다시 읽어도 정리 완료인데 또 409 면 오류(번역본 2번에서 멈춤)', () async {
      final repo = _ScriptedRepo(details: [_detail()], refinements: [_notReady]);
      final c = containerFor(repo);
      await expectLater(c.read(provider.future), throwsA(isA<AppException>()));
      expect(repo.refinementCalls, 2);
    });

    test('첫 열람(정제 단계)이면 상세를 다시 읽고 목록을 새로 고친다', () async {
      final repo = _ScriptedRepo(
        details: [_detail(), _detail(stage: InquiryStage.teacherConfirmed)],
      );
      final c = containerFor(repo);
      c.listen(teacherInquiriesViewModelProvider, (_, _) {});
      await c.read(teacherInquiriesViewModelProvider.future);
      final before = repo.listCalls;

      final s = await c.read(provider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(s.view.detail.summary.stage, InquiryStage.teacherConfirmed);
      expect(repo.listCalls, greaterThan(before));
    });

    test('번역본을 받은 뒤 상세 재조회가 실패해도 목록 새로 고침은 일어난다(코드 리뷰 1)', () async {
      final repo = _ScriptedRepo(details: [_detail()])
        ..detailErrors[2] = const AppException(message: '불러오지 못했습니다.');
      final c = containerFor(repo);
      c.listen(teacherInquiriesViewModelProvider, (_, _) {});
      await c.read(teacherInquiriesViewModelProvider.future);
      final before = repo.listCalls;

      await expectLater(c.read(provider.future), throwsA(isA<AppException>()));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.refinementCalls, 1);
      expect(repo.listCalls, greaterThan(before));
    });

    test('긴급이 아닌데 정리 상태가 비어 있으면 긴급으로 보내지 않고 오류(코드 리뷰 2)', () async {
      final repo = _ScriptedRepo(
        details: [_detail(status: null, stage: InquiryStage.received, urgent: false)],
      );
      final c = containerFor(repo);
      await expectLater(c.read(provider.future), throwsA(isA<AppException>()));
      expect(repo.refinementCalls, 0);
    });

    test('긴급 문의면 UrgentRedirect', () async {
      final repo = _ScriptedRepo(details: [_detail(status: null, stage: InquiryStage.delivered)]);
      final c = containerFor(repo);
      expect((await c.read(provider.future)).view, isA<UrgentRedirect>());
      expect(repo.refinementCalls, 0);
    });
  });

  group('원문 확인 필요·다시 정리하기', () {
    final needs = _detail(
      status: RefinementStatus.needsOriginal,
      stage: InquiryStage.received,
      retryAvailable: true,
    );

    test('원문 확인 필요는 번역본을 부르지 않는다', () async {
      final repo = _ScriptedRepo(details: [needs]);
      final c = containerFor(repo);
      final s = await c.read(provider.future);
      expect(s.view, isA<NeedsOriginal>());
      expect(s.view.detail.retryAvailable, isTrue);
      expect(repo.refinementCalls, 0);
    });

    test('202 정리 중 → 다시 정리하는 중(afterRetry)', () async {
      final repo = _ScriptedRepo(details: [needs]);
      final c = containerFor(repo);
      await c.read(provider.future);
      await c.read(provider.notifier).retry();
      final view = c.read(provider).value!.view;
      expect(view, isA<Refining>());
      expect((view as Refining).afterRetry, isTrue);
    });

    test('연타해도 요청은 한 번, 요청 중에는 isRetrying', () async {
      final repo = _ScriptedRepo(details: [needs])..retryGate = Completer();
      final c = containerFor(repo);
      await c.read(provider.future);
      final vm = c.read(provider.notifier);
      final first = vm.retry();
      unawaited(vm.retry());
      expect(c.read(provider).value!.isRetrying, isTrue);
      repo.retryGate!.complete();
      await first;
      expect(repo.retryCalls, 1);
    });

    test('409 RETRY_UNAVAILABLE → 서버 안내 + 최신 상태(버튼 없음)', () async {
      final repo = _ScriptedRepo(
        details: [
          needs,
          _detail(status: RefinementStatus.needsOriginal, stage: InquiryStage.received),
        ],
      )..retryResult = () => throw const AppException(
          message: '다시 정리할 수 없는 문의입니다.',
          code: ErrorCodes.refinementRetryUnavailable,
          statusCode: 409,
        );
      final c = containerFor(repo);
      await c.read(provider.future);
      await c.read(provider.notifier).retry();
      final s = c.read(provider).value!;
      expect(s.message, '다시 정리할 수 없는 문의입니다.');
      expect(s.view.detail.retryAvailable, isFalse);
      expect(s.isRetrying, isFalse);
    });

    test('네트워크 오류 → 안내만, 버튼은 다시 누를 수 있다', () async {
      final repo = _ScriptedRepo(details: [needs])
        ..retryResult = () => throw const AppException(message: '네트워크 연결을 확인해 주세요.');
      final c = containerFor(repo);
      await c.read(provider.future);
      await c.read(provider.notifier).retry();
      final s = c.read(provider).value!;
      expect(s.message, '네트워크 연결을 확인해 주세요.');
      expect(s.view, isA<NeedsOriginal>());
      expect(s.view.detail.retryAvailable, isTrue);
      expect(s.isRetrying, isFalse);
      expect(repo.detailCalls, 1);
    });

    test('202 인데 이미 정리 완료 → 상세를 다시 읽어 Refined', () async {
      final repo = _ScriptedRepo(
        details: [needs, _detail(stage: InquiryStage.teacherConfirmed)],
      )..retryResult = () => RefinementStatus.refined;
      final c = containerFor(repo);
      await c.read(provider.future);
      await c.read(provider.notifier).retry();
      expect(c.read(provider).value!.view, isA<Refined>());
    });

    test('받아들인 뒤 결과를 읽지 못하면 다시 정리하는 중에 머문다(코드 리뷰 3)', () async {
      final repo = _ScriptedRepo(details: [needs])
        ..retryResult = (() => RefinementStatus.refined)
        ..detailErrors[2] = const AppException(message: '불러오지 못했습니다.');
      final c = containerFor(repo);
      await c.read(provider.future);
      await c.read(provider.notifier).retry();
      final s = c.read(provider).value!;
      expect(s.view, isA<Refining>());
      expect((s.view as Refining).afterRetry, isTrue);
      expect(s.message, '불러오지 못했습니다.');
      expect(s.isRetrying, isFalse);
    });

    test('다시 확인하는 동안 보던 화면을 유지한다', () async {
      final repo = _ScriptedRepo(details: [needs]);
      final c = containerFor(repo);
      await c.read(provider.future);
      repo.detailGate = Completer();
      final pending = c.read(provider.notifier).recheck();
      final during = c.read(provider);
      expect(during.value!.isRechecking, isTrue);
      expect(during.value!.view, isA<NeedsOriginal>());
      repo.detailGate!.complete();
      await pending;
      expect(c.read(provider).value!.isRechecking, isFalse);
    });

    test('clearMessage 는 안내를 지운다', () async {
      final repo = _ScriptedRepo(details: [needs])
        ..retryResult = () => throw const AppException(message: '안내');
      final c = containerFor(repo);
      await c.read(provider.future);
      await c.read(provider.notifier).retry();
      c.read(provider.notifier).clearMessage();
      expect(c.read(provider).value!.message, isNull);
    });
  });

  group('mock 데모(research R10)', () {
    ProviderContainer mockContainer(String id) {
      final repo = MockTeacherInquiryRepository(TokenStore(), MockInquiryStore());
      final c = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [teacherInquiryRepositoryProvider.overrideWithValue(repo)],
      );
      c.listen(generalDetailViewModelProvider(id), (_, _) {});
      return c;
    }

    Future<GeneralDetail> retryThenRecheck(String id) async {
      final c = mockContainer(id);
      final p = generalDetailViewModelProvider(id);
      await c.read(p.future);
      await c.read(p.notifier).retry();
      expect((c.read(p).value!.view as Refining).afterRetry, isTrue);
      await c.read(p.notifier).recheck();
      return c.read(p).value!.view;
    }

    test('…0004 다시 정리하기 성공 → 다시 확인하면 번역본', () async {
      expect(
        await retryThenRecheck('a1000000-0000-4000-8000-000000000004'),
        isA<Refined>(),
      );
    });

    test('…0006 다시 정리하기 실패 → 다시 확인하면 버튼 없는 원문 확인 필요', () async {
      final view = await retryThenRecheck('a1000000-0000-4000-8000-000000000006');
      expect(view, isA<NeedsOriginal>());
      expect(view.detail.retryAvailable, isFalse);
    });
  });

  group('정리 중', () {
    const pendingId = 'a1000000-0000-4000-8000-00000000000a';

    test('정리 중 → Refining(afterRetry: false), 번역본을 부르지 않는다', () async {
      final repo = _ScriptedRepo(
        details: [_detail(status: RefinementStatus.pending, stage: InquiryStage.received)],
      );
      final c = containerFor(repo);
      final view = (await c.read(provider.future)).view;
      expect(view, isA<Refining>());
      expect((view as Refining).afterRetry, isFalse);
      expect(repo.refinementCalls, 0);
    });

    test('아무것도 안 하면 다시 읽지 않는다(자동 조회 없음)', () async {
      final repo = _ScriptedRepo(
        details: [_detail(status: RefinementStatus.pending, stage: InquiryStage.received)],
      );
      final c = containerFor(repo);
      expect((await c.read(provider.future)).view, isA<Refining>());
      final calls = repo.detailCalls;
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(repo.detailCalls, calls);
    });

    test('…000a 다시 확인 → 번역본, 열기 전 목록 새로 고침과 무관', () async {
      final store = MockInquiryStore();
      for (var n = 0; n < 3; n++) {
        store.listForTeacher(page: 0, size: 50);
      }
      final repo = MockTeacherInquiryRepository(TokenStore(), store);
      final c = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [teacherInquiryRepositoryProvider.overrideWithValue(repo)],
      );
      final p = generalDetailViewModelProvider(pendingId);
      c.listen(p, (_, _) {});
      expect((await c.read(p.future)).view, isA<Refining>());
      await c.read(p.notifier).recheck();
      expect(c.read(p).value!.view, isA<Refined>());
    });
  });
}
