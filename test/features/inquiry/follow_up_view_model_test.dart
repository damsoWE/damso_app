import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/presentation/parent/follow_up_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _root = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';

/// 보낸 키·본문을 기록하고 [next]로 결과를 정하는 가짜 Repository.
class _FakeRepo implements ParentInquiryRepository {
  final keys = <String>[];
  final contents = <String>[];
  FutureOr<FollowUpSubmitted> Function() next = () => _submitted;
  Completer<void>? gate;

  static final _submitted = FollowUpSubmitted(
    inquiryId: 'f1',
    threadRootId: _root,
    urgent: false,
    submittedAt: DateTime(2026, 10, 29),
    notices: const [Notice.received],
    hotlines: const [],
  );

  @override
  Future<FollowUpSubmitted> submitFollowUp({
    required String inquiryId,
    required String content,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    contents.add(content);
    await gate?.future;
    return next();
  }

  @override
  Future<ParentInquiryDetail> detail(String inquiryId) => throw UnimplementedError();

  @override
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<List<ParentInquirySummary>> list() async => const [];
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;
  final provider = followUpViewModelProvider(_root);

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [parentInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(provider, (_, _) {});
  });

  FollowUpViewModel vm() => container.read(provider.notifier);
  FollowUpState state() => container.read(provider);

  test('빈 내용·공백만·2,000자 초과는 보낼 수 없다', () {
    vm().onChanged('');
    expect(state().canSend, isFalse);
    vm().onChanged('   ');
    expect(state().canSend, isFalse);
    vm().onChanged('가' * 2000);
    expect(state().canSend, isTrue);
    vm().onChanged('가' * 2001);
    expect(state().tooLong, isTrue);
    expect(state().canSend, isFalse);
  });

  test('await 없이 두 번 보내도 한 번만 나간다', () async {
    repo.gate = Completer<void>();
    final first = vm().send('질문');
    final second = vm().send('질문');
    expect(await second, isNull);
    repo.gate!.complete();
    expect(await first, isNotNull);
    expect(repo.keys, hasLength(1));
  });

  test('실패 뒤 같은 내용은 같은 키, 내용이 바뀌면 새 키, 성공 뒤 새 키', () async {
    repo.next = () => throw const AppException(message: '네트워크', isNetworkError: true);
    await vm().send(' 질문 ');
    await vm().send('질문');
    expect(repo.keys[0], repo.keys[1]);
    expect(repo.contents, ['질문', '질문']);

    await vm().send('질문!');
    expect(repo.keys[2], isNot(repo.keys[1]));

    repo.next = () => _FakeRepo._submitted;
    await vm().send('질문!');
    expect(repo.keys[3], repo.keys[2]); // 실패했던 같은 내용 재전송은 같은 키
    await vm().send('질문!');
    expect(repo.keys[4], isNot(repo.keys[3])); // 성공 뒤에는 새 키
  });

  test('429 retryAfter 동안 보낼 수 없고 서버 메시지를 보인다', () async {
    repo.next = () => throw const AppException(
      message: '잠시 후 다시 시도해 주세요.',
      code: ErrorCodes.tooManyAttempts,
      statusCode: 429,
      retryAfter: Duration(seconds: 30),
    );
    expect(await vm().send('질문'), isNull);
    expect(state().errorMessage, '잠시 후 다시 시도해 주세요.');
    expect(state().cooldown.isActive, isTrue);
    expect(state().canSend, isFalse);
  });

  test('409·400 → 서버 메시지, 다시 보낼 수 있다', () async {
    for (final (status, code) in [(409, 'THREAD_CLOSED'), (400, 'INVALID_INPUT')]) {
      repo.next = () =>
          throw AppException(message: '안내 $status', code: code, statusCode: status);
      expect(await vm().send('질문'), isNull);
      expect(state().errorMessage, '안내 $status');
      expect(state().sending, isFalse);
      expect(state().canSend, isTrue);
    }
  });

  test('성공 → done 에 FollowUpSubmitted', () async {
    final result = await vm().send('질문');
    expect(result?.threadRootId, _root);
    expect(state().done, same(result));
    expect(state().sending, isFalse);
  });
}
