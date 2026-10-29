import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/presentation/parent/compose_view_model.dart';
import 'package:damso_app/features/parent/domain/child.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _child = Child(
  studentId: '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51',
  studentName: '김하나',
  classroom: ClassroomRef(classroomId: 'c', grade: 3, classNumber: 2),
  teacher: TeacherPublicProfile(displayName: '이담임', introduction: ''),
);

/// 보낸 키·본문을 기록하고 [next]로 결과를 정하는 가짜 Repository.
class _FakeRepo implements ParentInquiryRepository {
  final keys = <String>[];
  final contents = <String>[];
  FutureOr<InquirySubmitted> Function() next = () => _submitted;
  Completer<void>? gate;

  static final _submitted = InquirySubmitted(
    inquiryId: 'id',
    urgent: false,
    stage: InquiryStage.received,
    submittedAt: DateTime(2026, 10, 26),
    notices: const [Notice.received],
    hotlines: const [],
  );

  @override
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    contents.add(content);
    await gate?.future;
    return next();
  }

  @override
  Future<List<ParentInquirySummary>> list() async => const [];

  @override
  Future<ParentInquiryDetail> detail(String inquiryId) => throw UnimplementedError();

  @override
  Future<FollowUpSubmitted> submitFollowUp({
    required String inquiryId,
    required String content,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;
  final provider = composeViewModelProvider(_child);

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [parentInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(provider, (_, _) {});
  });

  ComposeViewModel vm() => container.read(provider.notifier);
  ComposeState state() => container.read(provider);

  test('길이: 비었거나 공백뿐이면 보낼 수 없고, 이모지 포함 2,000자까지 보낼 수 있다', () {
    vm().onChanged('   ');
    expect(state().canSubmit, isFalse);

    vm().onChanged('😀' * 2000); // 코드 포인트 2,000개(UTF-16 으로는 4,000)
    expect(state().length, 2000);
    expect(state().canSubmit, isTrue);

    vm().onChanged('😀' * 2001);
    expect(state().tooLong, isTrue);
    expect(state().canSubmit, isFalse);
  });

  test('같은 본문 재시도는 같은 키, 본문이 바뀌면 새 키, 성공하면 키를 버린다', () async {
    repo.next = () => throw const AppException(message: '네트워크', isNetworkError: true);
    await vm().submit(' 안녕하세요 ');
    await vm().submit('안녕하세요');
    expect(repo.keys[0], repo.keys[1]);
    expect(repo.contents, ['안녕하세요', '안녕하세요']);

    await vm().submit('안녕하세요!');
    expect(repo.keys[2], isNot(repo.keys[1]));

    repo.next = () => _FakeRepo._submitted;
    expect(await vm().submit('안녕하세요!'), isNotNull);
    expect(repo.keys[3], repo.keys[2]);

    await vm().submit('안녕하세요!');
    expect(repo.keys[4], isNot(repo.keys[3])); // 성공 뒤에는 새 제출
  });

  test('보내는 중에는 두 번째 보내기를 무시한다', () async {
    repo.gate = Completer<void>();
    final first = vm().submit('본문');
    expect(state().isSubmitting, isTrue);
    expect(await vm().submit('본문'), isNull);
    repo.gate!.complete();
    expect(await first, isNotNull);
    expect(repo.keys, hasLength(1));
  });

  test('429 → 남은 시간 표시, 쓴 키 유지', () async {
    repo.next = () => throw const AppException(
      message: '잠시 후 다시 시도해 주세요.',
      code: ErrorCodes.tooManyAttempts,
      statusCode: 429,
      retryAfter: Duration(seconds: 30),
    );
    expect(await vm().submit('본문'), isNull);
    expect(state().cooldown.isActive, isTrue);
    expect(state().canSubmit, isTrue); // 긴급은 제한이 없으므로 막지 않는다
    expect(state().errorMessage, '잠시 후 다시 시도해 주세요.');
  });

  test('409(담임 없음·같은 키 다른 내용)·네트워크 오류 → 서버 안내, 보내기 다시 가능', () async {
    for (final e in const [
      AppException(message: '담임 선생님이 아직 연결되지 않았습니다.', code: ErrorCodes.noHomeroomTeacher),
      AppException(message: '이미 다른 내용으로 보낸 요청입니다.', code: ErrorCodes.conflict),
    ]) {
      repo.next = () => throw e;
      expect(await vm().submit('본문'), isNull);
      expect(state().errorMessage, e.message);
      expect(state().isSubmitting, isFalse);
      expect(state().showTimeoutHint, isFalse);
    }
    repo.next = () => throw const AppException(
      message: AppException.networkMessage,
      isNetworkError: true,
    );
    await vm().submit('본문');
    expect(state().showTimeoutHint, isTrue); // research R3 시간 초과 안내
  });

  test('요청 중에 화면을 떠나도 예외 없이 끝난다', () async {
    final c = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [parentInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = c.listen(provider, (_, _) {});
    final pending = c.read(provider.notifier).submit('본문');
    sub.close();
    await c.pump();
    expect(await pending, isNotNull);
  });
}
