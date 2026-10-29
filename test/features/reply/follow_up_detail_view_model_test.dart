import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/teacher_inquiry_repository.dart';
import 'package:damso_app/features/reply/presentation/follow_up_detail_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _refinement = InquiryRefinement(
  inquiryId: 'f1',
  title: '중간 안내 요청',
  facts: '사실관계',
  requests: '중간 상황 안내',
  emotionLevel: null,
  emotionLabels: const [],
  refinedAt: DateTime(2026, 10, 28),
);

class _FakeRepo implements TeacherInquiryRepository {
  final calls = <String>[];
  Object Function() refinementResult = () => _refinement;

  @override
  Future<InquiryRefinement> refinement(String inquiryId) async {
    calls.add('refinement:$inquiryId');
    final r = refinementResult();
    if (r is InquiryRefinement) return r;
    throw r;
  }

  @override
  Future<String> content(String inquiryId) async {
    calls.add('content:$inquiryId');
    return '원문';
  }

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) => throw UnimplementedError();

  @override
  Future<TeacherInquiryPage> list({int page = 0, int size = TeacherInquiryRepository.pageSize}) =>
      throw UnimplementedError();

  @override
  Future<RefinementStatus> retryRefinement(String inquiryId) => throw UnimplementedError();
}

/// F4-3b 재문의 상세(specs/004 research R13).
void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [teacherInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  Future<FollowUpDetail> load({bool urgent = false}) {
    final provider = followUpDetailViewModelProvider((followUpId: 'f1', urgent: urgent));
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  test('번역본 있음 → Refined, 재문의 ID로 1회', () async {
    final d = await load();
    expect((d as Refined).refinement.requests, '중간 상황 안내');
    expect(repo.calls, ['refinement:f1']);
  });

  test('409 REFINEMENT_NOT_READY → NotRefined', () async {
    repo.refinementResult = () => const AppException(
      message: '아직 정리되지 않았습니다.',
      code: ErrorCodes.refinementNotReady,
      statusCode: 409,
    );
    expect(await load(), isA<NotRefined>());
  });

  test('긴급 재문의 → Urgent, 번역본을 부르지 않는다', () async {
    expect(await load(urgent: true), isA<Urgent>());
    expect(repo.calls, isEmpty);
  });

  test('어떤 경우든 원문은 부르지 않는다', () async {
    await load();
    expect(repo.calls.where((c) => c.startsWith('content')), isEmpty);
  });

  test('403 → 오류(서버 문구), 다시 시도하면 다시 요청', () async {
    repo.refinementResult = () => const AppException(
      message: '권한이 없습니다.',
      code: ErrorCodes.forbidden,
      statusCode: 403,
    );
    final provider = followUpDetailViewModelProvider((followUpId: 'f1', urgent: false));
    container.listen(provider, (_, _) {});
    await expectLater(container.read(provider.future), throwsA(isA<AppException>()));
    expect((container.read(provider).error! as AppException).message, '권한이 없습니다.');

    repo.refinementResult = () => _refinement;
    container.invalidate(provider);
    expect(await container.read(provider.future), isA<Refined>());
    expect(repo.calls, ['refinement:f1', 'refinement:f1']);
  });
}
