import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/teacher_inquiry_repository.dart';
import 'package:damso_app/features/reply/data/answer_repository_provider.dart';
import 'package:damso_app/features/reply/domain/answer_repository.dart';
import 'package:damso_app/features/reply/domain/answer_text.dart';
import 'package:damso_app/features/reply/domain/models.dart';
import 'package:damso_app/features/reply/presentation/answer_compose_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';

const _figmaText = '어제 일은 확인해 보니 큰 문제는 아니었습니다. 확인되는 대로 연락드리겠습니다.';

const _twoSuggestions = AnswerReview(
  available: true,
  highlights: [
    Highlight(
      excerpt: '어제 일은 확인해 보니 큰 문제는 아니었습니다.',
      reason: '걱정을 가볍게 여기는 말로 읽힐 수 있어요.',
      suggestion: '걱정 많으셨겠어요. 어제 상황을 아이들과 확인하고 있습니다.',
    ),
    Highlight(
      excerpt: '확인되는 대로 연락드리겠습니다.',
      reason: '“이번 주 안 회신” 요청에 대한 설명이 빠져 있어요.',
      suggestion: '확인한 내용을 이번 주 금요일까지 안내드리겠습니다.',
    ),
  ],
);

/// 호출을 기록하고 응답을 미리 정하는 가짜 Repository.
class _FakeAnswerRepo implements AnswerRepository {
  FutureOr<AnswerReview> Function() reviewResult = () => _twoSuggestions;
  FutureOr<AnswerSent> Function() sendResult = () => AnswerSent(
    answerId: 'a',
    inquiryId: _id,
    sentAt: DateTime(2026, 10, 28),
  );
  final reviews = <String>[];
  final sends = <({String content, bool reviewed})>[];

  /// 전송마다 보낸 lastSeenFollowUpId.
  final lastSeen = <String?>[];

  @override
  Future<AnswerReview> review(String inquiryId, String content) async {
    reviews.add(content);
    return reviewResult();
  }

  @override
  Future<AnswerSent> send(
    String inquiryId,
    String content, {
    required bool reviewed,
    required String? lastSeenFollowUpId,
  }) async {
    sends.add((content: content, reviewed: reviewed));
    lastSeen.add(lastSeenFollowUpId);
    return sendResult();
  }
}

TeacherFollowUp _followUp(String id, int minute) => TeacherFollowUp(
  inquiryId: id,
  urgent: false,
  title: '재문의 $id',
  stage: InquiryStage.refined,
  submittedAt: DateTime(2026, 10, 29, 10, minute),
);

/// 409 NEW_FOLLOW_UP 뒤 상세를 다시 받는 가짜 Repository. 상세만 쓴다.
class _FakeInquiryRepo implements TeacherInquiryRepository {
  List<TeacherFollowUp> followUps = const [];
  AppException? detailError;
  int detailCalls = 0;

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) async {
    detailCalls++;
    final error = detailError;
    if (error != null) throw error;
    return TeacherInquiryDetail(
      summary: TeacherInquirySummary(
        inquiryId: inquiryId,
        studentId: 's',
        studentName: '박서준',
        urgent: false,
        title: '친구 관계 관련 문의',
        stage: InquiryStage.teacherConfirmed,
        refinementStatus: RefinementStatus.refined,
        submittedAt: DateTime(2026, 10, 29, 9),
        hasAnswer: true,
        lastAnsweredAt: DateTime(2026, 10, 29, 9, 30),
      ),
      timeline: const [],
      retryAvailable: false,
      followUps: followUps,
    );
  }

  @override
  Future<TeacherInquiryPage> list({
    int page = 0,
    int size = TeacherInquiryRepository.pageSize,
    AnswerStatus? answerStatus,
  }) async => TeacherInquiryPage(items: const [], page: page, size: size, totalElements: 0);

  @override
  Future<String> content(String inquiryId) => throw UnimplementedError();

  @override
  Future<InquiryRefinement> refinement(String inquiryId) => throw UnimplementedError();

  @override
  Future<RefinementStatus> retryRefinement(String inquiryId) => throw UnimplementedError();
}

const _newFollowUpError = AppException(
  message: '확인하지 않은 재문의가 있습니다. 스레드를 다시 불러온 뒤 보내 주세요.',
  code: ErrorCodes.newFollowUp,
  statusCode: 409,
);

void main() {
  late _FakeAnswerRepo repo;
  late _FakeInquiryRepo inquiryRepo;
  late ProviderContainer container;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repo = _FakeAnswerRepo();
    inquiryRepo = _FakeInquiryRepo();
    container = ProviderContainer(
      overrides: [
        answerRepositoryProvider.overrideWithValue(repo),
        teacherInquiryRepositoryProvider.overrideWithValue(inquiryRepo),
        tokenStoreProvider.overrideWithValue(TokenStore()),
      ],
    );
    addTearDown(container.dispose);
  });

  final provider = answerComposeViewModelProvider(_id);
  AnswerComposeViewModel vm() => container.read(provider.notifier);
  ComposeState s() => container.read(provider);

  /// autoDispose 가 테스트 중 풀리지 않게 듣고 있는다(화면이 열려 있는 상태).
  void keepListening() => container.listen(provider, (_, _) {});

  group('작성·전송', () {
    setUp(keepListening);

    test('처음은 Editing, 빈 본문·공백만이면 점검할 수 없다', () {
      expect(s().step, isA<Editing>());
      expect(s().canReview, isFalse);
      vm().updateText('   ');
      expect(s().canReview, isFalse);
      vm().updateText('확인하겠습니다.');
      expect(s().canReview, isTrue);
    });

    test('점검 중에는 Reviewing, 다시 요청해도 1회, 본문은 잠긴다', () async {
      final gate = Completer<AnswerReview>();
      repo.reviewResult = () => gate.future;
      vm().updateText(_figmaText);
      final first = vm().review();
      unawaited(vm().review());
      expect(s().step, isA<Reviewing>());
      vm().updateText('바뀐 본문');
      expect(s().text, _figmaText);
      gate.complete(_twoSuggestions);
      await first;
      expect(repo.reviews, hasLength(1));
      expect(s().step, isA<Reviewed>());
    });

    test('입력 직후(Editing)에는 send 가 아무것도 하지 않는다', () async {
      vm().updateText('확인하겠습니다.');
      expect(s().canSend, isFalse);
      await vm().send();
      expect(repo.sends, isEmpty);
    });

    test('결과 상태에서 send 를 두 번 → 1회, 성공하면 sent, reviewed=true', () async {
      vm().updateText('확인하겠습니다.');
      await vm().review();
      final first = vm().send();
      unawaited(vm().send());
      await first;
      expect(repo.sends, hasLength(1));
      expect(repo.sends.single.reviewed, isTrue);
      expect(s().sent, isNotNull);
    });

    test('네트워크 오류 → SendFailed(다시 보내기 가능, 보내졌을 수 있음), 본문 유지', () async {
      repo.sendResult = () => throw const AppException(
        message: AppException.networkMessage,
        isNetworkError: true,
      );
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      final step = s().step as SendFailed;
      expect(step.canResend, isTrue);
      expect(step.maybeSent, isTrue);
      expect(s().text, '확인하겠습니다.');
    });

    test('409 THREAD_CLOSED → 다시 보내기 숨김, 서버 문구', () async {
      repo.sendResult = () => throw const AppException(
        message: '이미 종료된 문의입니다.',
        code: ErrorCodes.threadClosed,
        statusCode: 409,
      );
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      expect((s().step as SendFailed).canResend, isFalse);
      expect(s().message, '이미 종료된 문의입니다.');
      expect(s().canSend, isFalse);
    });

    test('400 → 입력칸 아래 오류, 고칠 수 있는 상태', () async {
      repo.sendResult = () => throw const AppException(
        message: '입력값이 올바르지 않습니다.',
        code: ErrorCodes.invalidInput,
        statusCode: 400,
        fieldErrors: {'content': '최대 2000자입니다'},
      );
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      expect(s().inputError, '최대 2000자입니다');
      expect(s().step, isA<EditedAfterReview>());
    });

    test('다시 보내기는 같은 본문으로 1회 더', () async {
      var fail = true;
      repo.sendResult = () {
        if (fail) {
          fail = false;
          throw const AppException(message: AppException.networkMessage, isNetworkError: true);
        }
        return AnswerSent(answerId: 'a', inquiryId: _id, sentAt: DateTime(2026));
      };
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      await vm().resend();
      expect(repo.sends.map((e) => e.content), ['확인하겠습니다.', '확인하겠습니다.']);
      expect(s().sent, isNotNull);
    });

    test('전송 중 화면이 닫혀도(구독 해제) 응답 처리를 마친다', () async {
      final gate = Completer<AnswerSent>();
      repo.sendResult = () => gate.future;
      final sub = container.listen(provider, (_, _) {});
      vm().updateText('확인하겠습니다.');
      await vm().review();
      final sending = vm().send();
      sub.close();
      gate.complete(AnswerSent(answerId: 'a', inquiryId: _id, sentAt: DateTime(2026)));
      await sending;
      expect(repo.sends, hasLength(1));
    });

    test('들어오기 전 화면의 마지막 재문의 ID 를 보낸다. 다시 넣어도 처음 값 그대로', () async {
      vm().seenFollowUp('f1');
      vm().seenFollowUp('f9'); // 다시 그려져도 바뀌지 않는다
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      expect(repo.lastSeen, ['f1']);
    });

    test('재문의가 없었으면 null 을 보낸다', () async {
      vm().seenFollowUp(null);
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      expect(repo.lastSeen, [null]);
    });

    test('409 NEW_FOLLOW_UP → 상세를 다시 받아 못 본 재문의만 보이고, 본문 유지·자동 전송 없음', () async {
      vm().seenFollowUp('f1');
      inquiryRepo.followUps = [_followUp('f1', 0), _followUp('f2', 5), _followUp('f3', 9)];
      repo.sendResult = () => throw _newFollowUpError;
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();

      final step = s().step as NewFollowUpArrived;
      expect(step.followUps.map((f) => f.inquiryId), ['f2', 'f3']);
      expect(step.notice, _newFollowUpError.message);
      expect(s().text, '확인하겠습니다.');
      expect(s().sent, isNull);
      expect(s().canSend, isTrue);
      expect(repo.sends, hasLength(1));
    });

    test('NEW_FOLLOW_UP 뒤 다시 보내면 새 마지막 재문의 ID 로 보낸다', () async {
      var first = true;
      repo.sendResult = () {
        if (first) {
          first = false;
          throw _newFollowUpError;
        }
        return AnswerSent(answerId: 'a', inquiryId: _id, sentAt: DateTime(2026));
      };
      vm().seenFollowUp(null);
      inquiryRepo.followUps = [_followUp('f1', 0)];
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      expect((s().step as NewFollowUpArrived).followUps.single.inquiryId, 'f1');

      await vm().resend();
      expect(repo.lastSeen, [null, 'f1']);
      expect(s().sent, isNotNull);
    });

    test('NEW_FOLLOW_UP 뒤 "답변 수정" → EditedAfterReview, 그대로 전송할 수 있다', () async {
      inquiryRepo.followUps = [_followUp('f1', 0)];
      repo.sendResult = () => throw _newFollowUpError;
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      vm().startEdit();
      expect(s().step, isA<EditedAfterReview>());
      expect(s().canSend, isTrue);
    });

    test('NEW_FOLLOW_UP 뒤 상세를 못 받으면 전송 실패(다시 보내기 가능)·서버 문구', () async {
      inquiryRepo.detailError = const AppException(message: '요청을 처리하지 못했습니다.');
      repo.sendResult = () => throw _newFollowUpError;
      vm().seenFollowUp('f1');
      vm().updateText('확인하겠습니다.');
      await vm().review();
      await vm().send();
      final step = s().step as SendFailed;
      expect(step.canResend, isTrue);
      expect(step.maybeSent, isFalse);
      expect(s().message, '요청을 처리하지 못했습니다.');

      // 다시 보내면 아직 본 재문의가 그대로라 서버가 또 막고, 그때 다시 받는다.
      inquiryRepo.detailError = null;
      inquiryRepo.followUps = [_followUp('f1', 0), _followUp('f2', 5)];
      await vm().resend();
      expect(repo.lastSeen, ['f1', 'f1']);
      expect((s().step as NewFollowUpArrived).followUps.single.inquiryId, 'f2');
    });

    test('같은 inquiryId 면 같은 ViewModel·본문(analyze U1)', () {
      vm().updateText('작성 중');
      expect(container.read(answerComposeViewModelProvider(_id)).text, '작성 중');
    });

    test('세션 만료 + 본문 있음 → 안내 값', () async {
      container.read(sessionControllerProvider.notifier).signIn(Role.teacher);
      vm().updateText('작성 중');
      await container.read(sessionControllerProvider.notifier).expire();
      expect(s().sessionExpiredNotice, AnswerText.sessionExpiredDraftLost);
    });
  });

  group('제안', () {
    setUp(keepListening);

    Future<void> reviewFigmaText() async {
      vm().updateText(_figmaText);
      await vm().review();
    }

    test('제안 2개 → Reviewed, 아직 바꾼 제안 없음', () async {
      await reviewFigmaText();
      final step = s().step as Reviewed;
      expect(step.review.highlights, hasLength(2));
      expect(step.applied, isEmpty);
    });

    test('apply(0) → 그 문장 한 곳만 바뀌고 기록된다, 다른 문장은 그대로', () async {
      await reviewFigmaText();
      vm().apply(0);
      expect(
        s().text,
        '걱정 많으셨겠어요. 어제 상황을 아이들과 확인하고 있습니다. 확인되는 대로 연락드리겠습니다.',
      );
      final step = s().step as Reviewed;
      expect(step.applied[0], (
        original: '어제 일은 확인해 보니 큰 문제는 아니었습니다.',
        replaced: '걱정 많으셨겠어요. 어제 상황을 아이들과 확인하고 있습니다.',
      ));
      expect(vm().canApply(0), isFalse);
    });

    test('같은 문장이 두 번 있으면 처음 한 곳만 바꾼다', () async {
      const twice = '확인되는 대로 연락드리겠습니다. 확인되는 대로 연락드리겠습니다.';
      vm().updateText(twice);
      await vm().review();
      vm().apply(1);
      expect(
        s().text,
        '확인한 내용을 이번 주 금요일까지 안내드리겠습니다. 확인되는 대로 연락드리겠습니다.',
      );
    });

    test('undo(0) → 원래 본문, 결과는 그대로', () async {
      await reviewFigmaText();
      vm().apply(0);
      vm().undo(0);
      expect(s().text, _figmaText);
      final step = s().step as Reviewed;
      expect(step.applied, isEmpty);
      expect(step.review.highlights, hasLength(2));
    });

    test('본문에 없는 문장이면 canApply false, apply 는 무시', () async {
      vm().updateText('다른 답변입니다.');
      await vm().review();
      expect(vm().canApply(0), isFalse);
      vm().apply(0);
      expect(s().text, '다른 답변입니다.');
      expect((s().step as Reviewed).applied, isEmpty);
    });

    test('결과 상태에서 직접 고치면 EditedAfterReview, 결과·바꾼 기록은 없어진다', () async {
      await reviewFigmaText();
      vm().apply(0);
      vm().updateText('${s().text} 감사합니다.');
      expect(s().step, isA<EditedAfterReview>());
      expect(vm().canApply(1), isFalse);
    });

    test('EditedAfterReview 에서 다시 점검 → Reviewing, 전송도 가능', () async {
      final gate = Completer<AnswerReview>();
      await reviewFigmaText();
      vm().startEdit();
      expect(s().step, isA<EditedAfterReview>());
      expect(s().canSend, isTrue);
      repo.reviewResult = () => gate.future;
      final again = vm().review();
      expect(s().step, isA<Reviewing>());
      gate.complete(const AnswerReview(available: true, highlights: []));
      await again;
      expect(repo.reviews, hasLength(2));
    });

    test('제안 0개 → Reviewed(빈 제안) = 제안 없음', () async {
      repo.reviewResult = () => const AnswerReview(available: true, highlights: []);
      vm().updateText('확인하겠습니다.');
      await vm().review();
      expect((s().step as Reviewed).review.highlights, isEmpty);
      expect(s().canSend, isTrue);
    });
  });

  group('점검 실패', () {
    setUp(keepListening);

    test('available false 면 제안이 와도 ReviewFailed, 본문 그대로', () async {
      repo.reviewResult = () => AnswerReview(
        available: false,
        highlights: _twoSuggestions.highlights,
      );
      vm().updateText(_figmaText);
      await vm().review();
      expect(s().step, isA<ReviewFailed>());
      expect(s().text, _figmaText);
      expect(s().message, isNull);
    });

    test('네트워크 오류 → ReviewFailed(오류 상태 아님), 안내 스낵바 없음', () async {
      repo.reviewResult = () => throw const AppException(
        message: AppException.networkMessage,
        isNetworkError: true,
      );
      vm().updateText(_figmaText);
      await vm().review();
      expect(s().step, isA<ReviewFailed>());
      expect(s().message, isNull);
      expect(s().text, _figmaText);
    });

    test('403 → 서버 문구 안내 + ReviewFailed', () async {
      repo.reviewResult = () => throw const AppException(
        message: '담당 학급이 없습니다.',
        code: ErrorCodes.forbidden,
        statusCode: 403,
      );
      vm().updateText(_figmaText);
      await vm().review();
      expect(s().step, isA<ReviewFailed>());
      expect(s().message, '담당 학급이 없습니다.');
      expect(s().text, _figmaText);
    });

    test('ReviewFailed 에서 다시 점검 → Reviewing, 직접 전송 → 1회·reviewed true', () async {
      final gate = Completer<AnswerReview>();
      var first = true;
      repo.reviewResult = () {
        if (first) {
          first = false;
          return const AnswerReview(available: false, highlights: []);
        }
        return gate.future;
      };
      vm().updateText(_figmaText);
      await vm().review();
      final again = vm().review();
      expect(s().step, isA<Reviewing>());
      gate.complete(const AnswerReview(available: false, highlights: []));
      await again;
      expect(s().step, isA<ReviewFailed>());

      await vm().send();
      expect(repo.sends, [(content: _figmaText, reviewed: true)]);
      expect(s().sent, isNotNull);
    });
  });

  // 점검 결과를 자동으로 반영하거나 자동으로 전송하지 않는다(원칙 V). fake 시계로 1분을 흘린다.
  testWidgets('어떤 결과든 시간이 지나도 본문·상태가 그대로다', (tester) async {
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    vm().updateText(_figmaText);
    await vm().review();
    await tester.pump(const Duration(minutes: 1));
    expect(s().text, _figmaText);
    expect((s().step as Reviewed).applied, isEmpty);
    expect(repo.sends, isEmpty);
  });
}
