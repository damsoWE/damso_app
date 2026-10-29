import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/teacher_inquiry_repository.dart';
import 'package:damso_app/features/reply/presentation/thread_view_model.dart';
import 'package:damso_app/features/teacher/data/teacher_repository_provider.dart';
import 'package:damso_app/features/teacher/domain/models.dart';
import 'package:damso_app/features/teacher/domain/teacher_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _rootId = 'root';

const _notReady = AppException(
  message: '아직 정리되지 않았습니다.',
  code: ErrorCodes.refinementNotReady,
  statusCode: 409,
);

InquiryRefinement refinementOf(String id, String requests) => InquiryRefinement(
  inquiryId: id,
  title: '정리된 제목',
  facts: '사실관계',
  requests: requests,
  emotionLevel: null,
  emotionLabels: const [],
  refinedAt: DateTime(2026, 10, 28),
);

TeacherFollowUp followUpOf(String id, DateTime at, {bool urgent = false}) => TeacherFollowUp(
  inquiryId: id,
  urgent: urgent,
  title: '재문의',
  stage: InquiryStage.refined,
  submittedAt: at,
);

SentAnswer answerAt(DateTime at) =>
    SentAnswer(answerId: 'a$at', content: '답변 $at', reviewed: true, sentAt: at);

TeacherInquiryDetail detailOf({
  bool urgent = false,
  RefinementStatus? status = RefinementStatus.refined,
  List<TeacherFollowUp> followUps = const [],
  List<SentAnswer> answers = const [],
}) => TeacherInquiryDetail(
  summary: TeacherInquirySummary(
    inquiryId: _rootId,
    studentId: 's',
    studentName: '김하나',
    urgent: urgent,
    title: '친구 관계 관련 문의',
    stage: InquiryStage.teacherConfirmed,
    refinementStatus: urgent ? null : status,
    submittedAt: DateTime(2026, 10, 28, 9),
    hasAnswer: answers.isNotEmpty,
    lastAnsweredAt: answers.isEmpty ? null : answers.last.sentAt,
  ),
  timeline: const [],
  retryAvailable: false,
  followUps: followUps,
  answers: answers,
);

/// 호출 순서를 기록하는 가짜 교사 문의 Repository.
class _FakeInquiryRepo implements TeacherInquiryRepository {
  _FakeInquiryRepo(this.calls);

  final List<String> calls;
  late TeacherInquiryDetail detailValue;
  final refinements = <String, FutureOr<InquiryRefinement> Function()>{};
  Completer<void>? detailGate;

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) async {
    calls.add('detail');
    await detailGate?.future;
    return detailValue;
  }

  @override
  Future<InquiryRefinement> refinement(String inquiryId) async {
    calls.add('refinement:$inquiryId');
    final f = refinements[inquiryId];
    if (f == null) throw _notReady;
    return f();
  }

  @override
  Future<String> content(String inquiryId) async {
    calls.add('content:$inquiryId');
    return '원문';
  }

  @override
  Future<TeacherInquiryPage> list({
    int page = 0,
    int size = TeacherInquiryRepository.pageSize,
    AnswerStatus? answerStatus,
  }) => throw UnimplementedError();

  @override
  Future<RefinementStatus> retryRefinement(String inquiryId) => throw UnimplementedError();
}

class _FakeTeacherRepo implements TeacherRepository {
  _FakeTeacherRepo(this.calls);

  final List<String> calls;
  bool fail = false;

  @override
  Future<TeacherProfile> getProfile() async {
    calls.add('profile');
    if (fail) throw const AppException(message: '서버 오류', statusCode: 500);
    return const TeacherProfile(displayName: '이담임', introduction: '');
  }

  @override
  Future<TeacherProfile> updateProfile(TeacherProfile profile) => throw UnimplementedError();

  @override
  Future<MyClassroom> getMyClassroom() => throw UnimplementedError();
}

void main() {
  late List<String> calls;
  late _FakeInquiryRepo repo;
  late _FakeTeacherRepo teacher;
  late ProviderContainer container;

  setUp(() {
    calls = [];
    repo = _FakeInquiryRepo(calls);
    teacher = _FakeTeacherRepo(calls);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        teacherInquiryRepositoryProvider.overrideWithValue(repo),
        teacherRepositoryProvider.overrideWithValue(teacher),
      ],
    );
    addTearDown(container.dispose);
  });

  final provider = threadViewModelProvider(_rootId);
  Future<ThreadState> load() {
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  final t = DateTime(2026, 10, 28, 10);

  test('카드 순서: 루트 → 답변·재문의 시간순', () async {
    repo.detailValue = detailOf(
      answers: [answerAt(t), answerAt(t.add(const Duration(hours: 2)))],
      followUps: [followUpOf('f1', t.add(const Duration(hours: 1)))],
    );
    final s = await load();
    expect(s.entries.map((e) => switch (e) {
      ParentCard(:final isFollowUp) => isFollowUp ? 'followUp' : 'root',
      AnswerCard() => 'answer',
    }), ['root', 'answer', 'followUp', 'answer']);
  });

  test('루트 REFINED → 번역본 1회, 요청사항 채움 / 빈 문자열이면 null', () async {
    repo.detailValue = detailOf(answers: [answerAt(t)]);
    repo.refinements[_rootId] = () => refinementOf(_rootId, '이번 주 안 회신');
    var s = await load();
    expect(calls.where((c) => c == 'refinement:$_rootId'), hasLength(1));
    expect((s.entries.first as ParentCard).requests, '이번 주 안 회신');

    // 다시 읽어도 이미 받은 번역본은 다시 부르지 않는다(열람 기록이 늘지 않게).
    await container.read(provider.notifier).reload();
    s = container.read(provider).requireValue;
    expect(calls.where((c) => c == 'refinement:$_rootId'), hasLength(1));
    expect((s.entries.first as ParentCard).requests, '이번 주 안 회신');
  });

  test('번역본 요청사항이 빈 문자열이면 null', () async {
    repo.detailValue = detailOf(answers: [answerAt(t)]);
    repo.refinements[_rootId] = () => refinementOf(_rootId, '');
    final s = await load();
    expect((s.entries.first as ParentCard).requests, isNull);
  });

  test('루트가 긴급이거나 NEEDS_ORIGINAL 이면 번역본을 부르지 않는다', () async {
    repo.detailValue = detailOf(urgent: true);
    var s = await load();
    expect((s.entries.first as ParentCard).requests, isNull);

    repo.detailValue = detailOf(status: RefinementStatus.needsOriginal);
    container.invalidate(provider);
    s = await load();
    expect((s.entries.first as ParentCard).requests, isNull);
    expect(calls.where((c) => c.startsWith('refinement')), isEmpty);
  });

  test('재문의 번역본 409 → 그 카드 요청사항 null, 화면은 열린다', () async {
    repo.detailValue = detailOf(
      answers: [answerAt(t)],
      followUps: [followUpOf('f1', t.add(const Duration(hours: 1)))],
    );
    repo.refinements[_rootId] = () => refinementOf(_rootId, '루트 요청');
    final s = await load();
    final followUp = s.entries.last as ParentCard;
    expect(followUp.isFollowUp, isTrue);
    expect(followUp.requests, isNull);
    expect(calls, contains('refinement:f1'));
  });

  test('긴급 재문의는 번역본을 부르지 않는다', () async {
    repo.detailValue = detailOf(
      answers: [answerAt(t)],
      followUps: [followUpOf('f1', t.add(const Duration(hours: 1)), urgent: true)],
    );
    await load();
    expect(calls, isNot(contains('refinement:f1')));
  });

  test('재문의 번역본이 있으면 그 요청사항', () async {
    repo.detailValue = detailOf(
      answers: [answerAt(t)],
      followUps: [followUpOf('f1', t.add(const Duration(hours: 1)))],
    );
    repo.refinements['f1'] = () => refinementOf('f1', '중간 안내 요청');
    final s = await load();
    expect((s.entries.last as ParentCard).requests, '중간 안내 요청');
  });

  test('교사 프로필 실패 → teacherName null, 화면은 열린다', () async {
    teacher.fail = true;
    repo.detailValue = detailOf(answers: [answerAt(t)]);
    final s = await load();
    expect(s.teacherName, isNull);
    expect(s.entries, isNotEmpty);
  });

  test('프로필 성공 → 표시 이름', () async {
    repo.detailValue = detailOf(answers: [answerAt(t)]);
    expect((await load()).teacherName, '이담임');
  });

  test('unanswered 는 마지막 답변보다 늦은 재문의만', () async {
    repo.detailValue = detailOf(
      answers: [answerAt(t), answerAt(t.add(const Duration(hours: 2)))],
      followUps: [
        followUpOf('f1', t.add(const Duration(hours: 1))),
        followUpOf('f2', t.add(const Duration(hours: 3))),
      ],
    );
    final s = await load();
    final followUps = s.entries.whereType<ParentCard>().where((c) => c.isFollowUp).toList();
    expect(followUps.map((c) => (c.inquiryId, c.unanswered)), [('f1', false), ('f2', true)]);
  });

  test('원문은 부르지 않는다', () async {
    repo.detailValue = detailOf(
      answers: [answerAt(t)],
      followUps: [followUpOf('f1', t.add(const Duration(hours: 1)))],
    );
    await load();
    expect(calls.where((c) => c.startsWith('content')), isEmpty);
  });

  test('상세와 프로필은 함께 시작한다(상세 응답을 기다리지 않는다)', () async {
    repo.detailGate = Completer<void>();
    repo.detailValue = detailOf(answers: [answerAt(t)]);
    container.listen(provider, (_, _) {});
    final future = container.read(provider.future);
    await Future<void>.delayed(Duration.zero);
    expect(calls, containsAll(['detail', 'profile']));
    repo.detailGate!.complete();
    await future;
  });
}
