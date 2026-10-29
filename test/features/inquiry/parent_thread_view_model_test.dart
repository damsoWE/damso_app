import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/presentation/parent/thread_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';

/// 상세 호출 횟수를 세고 [next]로 결과를 정하는 가짜 Repository.
class _FakeRepo implements ParentInquiryRepository {
  int detailCalls = 0;
  Future<ParentInquiryDetail> Function() next = () async => _detail;

  static final _detail = ParentInquiryDetail(
    summary: ParentInquirySummary(
      inquiryId: _id,
      studentId: 's',
      studentName: '김하나',
      urgent: false,
      stage: InquiryStage.received,
      submittedAt: DateTime(2026, 10, 26),
      hasAnswer: false,
      lastAnsweredAt: null,
    ),
    timeline: const [],
    notices: const [],
    hotlines: const [],
    content: '처음 문의',
    followUps: const [],
    answers: const [],
  );

  @override
  Future<ParentInquiryDetail> detail(String inquiryId) {
    detailCalls++;
    return next();
  }

  @override
  Future<FollowUpSubmitted> submitFollowUp({
    required String inquiryId,
    required String content,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<List<ParentInquirySummary>> list() => throw UnimplementedError();
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;
  final provider = parentThreadViewModelProvider(_id);

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [parentInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(provider, (_, _) {});
  });

  test('로드 성공 → AsyncData(detail)', () async {
    final detail = await container.read(provider.future);
    expect(detail.content, '처음 문의');
    expect(container.read(provider), isA<AsyncData<ParentInquiryDetail>>());
  });

  test('403 → AsyncError, 서버 메시지 그대로', () async {
    repo.next = () async => throw const AppException(
      message: '접근 권한이 없습니다.',
      statusCode: 403,
    );
    container.invalidate(provider); // setUp 의 첫 로드는 성공 응답이었다
    await expectLater(container.read(provider.future), throwsA(isA<AppException>()));
    final state = container.read(provider);
    expect(state, isA<AsyncError<ParentInquiryDetail>>());
    expect((state.error! as AppException).message, '접근 권한이 없습니다.');
  });

  test('reload() → 상세를 다시 부르고, 실패해도 예외를 던지지 않는다', () async {
    await container.read(provider.future);
    await container.read(provider.notifier).reload();
    expect(repo.detailCalls, 2);

    repo.next = () async => throw const AppException(message: '실패');
    await container.read(provider.notifier).reload();
    expect(container.read(provider), isA<AsyncError<ParentInquiryDetail>>());
  });
}
