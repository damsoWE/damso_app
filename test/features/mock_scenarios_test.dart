import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/data/mock_teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/reply/data/mock_answer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

SessionState sessionOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(sessionControllerProvider);

/// US8: 서버 없이 mock 만으로 정상·오류·잠금·권한 없음·세션 만료를 재현한다(FR-012, SC-007).
void main() {
  testWidgets('세션 만료(갱신 거부) → 로그인 화면, 보호 화면으로 다시 가도 로그인 화면', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'expired@damso.test');

    expect(find.text('학부모 홈'), findsNothing);
    expect(find.widgetWithText(TextField, '이메일'), findsOneWidget); // C-1
    expect(sessionOf(tester), const SignedOut(sessionExpired: true));

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/parent');
    await tester.pumpAndSettle();
    expect(find.text('학부모 홈'), findsNothing);
    expect(find.widgetWithText(TextField, '이메일'), findsOneWidget);
  });

  testWidgets('접근 권한 만료 → 갱신 → 재시도 성공은 오류 없이 홈을 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'refresh@damso.test');

    expect(find.text('학부모 홈'), findsOneWidget);
    expect(find.text('김하나'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(sessionOf(tester), const SignedIn(Role.parent));
  });

  testWidgets('담당 학급이 없는 교사는 권한 없음 안내를 본다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'noclass@damso.test');
    await tester.tap(find.byTooltip('마이페이지'));
    await tester.pumpAndSettle();
    await tapText(tester, '학부모 연결 현황');
    expect(find.text('권한이 없습니다.'), findsOneWidget);
  });

  testWidgets('로그인 대기는 서버가 준 남은 시간을 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'wait@damso.test', password: 'x');
    expect(find.text('30초 후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(isEnabled(tester, '로그인'), isFalse);

    await tester.pump(const Duration(seconds: 30));
    expect(isEnabled(tester, '로그인'), isTrue);
  });

  testWidgets('초대 코드 잠금은 남은 시간을 보이고 확인 버튼을 막는다', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tapText(tester, '초대코드로 가입하기');
    await enterField(tester, '초대 코드', 'ZZZZZZZZZZ');
    await enterField(tester, '이메일', 'new@damso.test');
    await tapText(tester, '코드 확인');

    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('10분 0초 후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(isEnabled(tester, '코드 확인'), isFalse);
  });

  group('F2 문의 mock 저장소 (quickstart "mock 데모 입력")', () {
    const hana = '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51';
    const duri = '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e52';
    late MockInquiryStore store;
    var key = 0;

    InquirySubmitted send(String content, {String student = hana, String? k}) =>
        store.submit(
          parentAccount: 'parent',
          studentId: student,
          content: content,
          idempotencyKey: k ?? 'k${key++}',
        );

    setUp(() => store = MockInquiryStore());

    test('본문 단어별 결과 6종', () {
      expect(send('준비물 문의').outcome, isA<ReceivedNotice>());
      store = MockInquiryStore();
      expect(send('밤늦게 죄송해요').outcome, isA<DeferredNotice>());
      final cases = {
        '자해': [Hotline.suicidePrevention],
        '학대': [Hotline.childAbuse],
        '위험': <Hotline>[],
        '긴급': [Hotline.childAbuse, Hotline.suicidePrevention],
      };
      for (final MapEntry(key: word, value: hotlines) in cases.entries) {
        final outcome = send('$word 관련 문의').outcome;
        expect(outcome, isA<UrgentNotice>(), reason: word);
        expect((outcome as UrgentNotice).hotlines, hotlines, reason: word);
      }
    });

    test('60초 안 두 번째 일반 문의는 429, 긴급은 통과, 같은 키는 같은 결과', () {
      final first = send('첫 문의', k: 'same');
      expect(send('첫 문의', k: 'same').inquiryId, first.inquiryId);
      expect(
        () => send('두 번째 문의'),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 429)),
      );
      expect(send('자해가 걱정돼요').urgent, isTrue);
      expect(
        () => send('다른 내용', k: 'same'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'CONFLICT')),
      );
    });

    test('담임 없는 자녀(김두리)는 409', () {
      expect(
        () => send('문의', student: duri),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'NO_HOMEROOM_TEACHER'),
        ),
      );
    });

    test('학부모가 보낸 문의가 교사 목록에 보이고, 긴급은 맨 위', () {
      final sent = send('자해 걱정');
      final page = store.listForTeacher(page: 0, size: 20);
      expect(page.items.first.inquiryId, sent.inquiryId);
      expect(page.items.where((i) => i.title == '원문 확인 필요'), isNotEmpty);
      expect(page.totalElements, greaterThan(25));
      expect(page.hasMore, isTrue);
    });

    test('교사 두 번째 조회부터 "정리 중"이 정리 완료로, 학부모 단계는 접수 → 정제', () {
      const pending = 'a1000000-0000-4000-8000-000000000003';
      TeacherInquirySummary find(TeacherInquiryPage p) =>
          p.items.firstWhere((i) => i.inquiryId == pending);
      expect(find(store.listForTeacher(page: 0, size: 50)).title, '정리 중');
      final second = find(store.listForTeacher(page: 0, size: 50));
      expect(second.refinementStatus, RefinementStatus.refined);
      expect(
        store.listForParent('parent').firstWhere((s) => s.inquiryId == pending).stage,
        InquiryStage.refined,
      );
    });

    test('권한 확인(데모) 상세는 403', () {
      expect(
        () => store.detailForParent('parent', MockInquiryStore.forbiddenDemoId),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 403)),
      );
    });
  });

  group('F3 mock 저장소 규칙 (specs/003 research R10)', () {
    const pending = 'a1000000-0000-4000-8000-00000000000a';
    const retryOk = 'a1000000-0000-4000-8000-000000000004';
    const refinedFresh = 'a1000000-0000-4000-8000-000000000008';
    const refinedNoRequests = 'a1000000-0000-4000-8000-000000000009';
    const urgent = 'a1000000-0000-4000-8000-000000000001';
    late MockInquiryStore store;

    setUp(() => store = MockInquiryStore());

    Matcher appCode(String code) =>
        throwsA(isA<AppException>().having((e) => e.code, 'code', code));

    List<InquiryStage> stages(String id) =>
        store.detailForTeacher(id).timeline.map((e) => e.stage).toList();

    test('정리 완료가 아닌 문의의 번역본은 409', () {
      expect(
        () => store.refinementForTeacher(pending),
        appCode(ErrorCodes.refinementNotReady),
      );
    });

    test('번역본 첫 열람에 "교사 확인", 두 번째 열람은 이력 그대로', () {
      expect(store.refinementForTeacher(refinedFresh).emotionLevel, EmotionLevel.high);
      expect(stages(refinedFresh).last, InquiryStage.teacherConfirmed);
      final count = stages(refinedFresh).length;
      store.refinementForTeacher(refinedFresh);
      expect(stages(refinedFresh), hasLength(count));
    });

    test('원문 확인 필요 문의는 원문 첫 열람에 접수 → 교사 확인, 번역본 있는 문의는 그대로', () {
      store.contentForTeacher(retryOk);
      expect(stages(retryOk), [InquiryStage.received, InquiryStage.teacherConfirmed]);

      store.contentForTeacher(refinedNoRequests);
      expect(stages(refinedNoRequests).last, InquiryStage.refined);
    });

    test('다시 정리하기는 1회: 정리 중으로 바뀌고 두 번째는 409', () {
      expect(store.retryForTeacher(retryOk), RefinementStatus.pending);
      expect(
        () => store.retryForTeacher(retryOk),
        appCode(ErrorCodes.refinementRetryUnavailable),
      );
    });

    test('긴급 문의는 다시 정리할 수 없다(409)', () {
      expect(
        () => store.retryForTeacher(urgent),
        appCode(ErrorCodes.refinementRetryUnavailable),
      );
    });

    test('US5: 교사가 번역본을 연 뒤 학부모 타임라인은 접수 → 정제 → 교사 확인', () {
      store.refinementForTeacher(refinedNoRequests);
      expect(
        store
            .detailForParent('parent', refinedNoRequests)
            .timeline
            .map((e) => e.stage),
        [InquiryStage.received, InquiryStage.refined, InquiryStage.teacherConfirmed],
      );
    });

    test('교사가 원문을 연 뒤 다시 정리하기가 성공해도 "정제"는 더하지 않는다', () {
      store.contentForTeacher(retryOk); // 접수 → 교사 확인
      store.retryForTeacher(retryOk);
      final d = store.detailForTeacher(retryOk);
      expect(d.summary.refinementStatus, RefinementStatus.refined);
      expect(
        d.timeline.map((e) => e.stage),
        [InquiryStage.received, InquiryStage.teacherConfirmed],
      );
    });
  });

  group('F3 데모 문의 (specs/003 research R10, quickstart 표)', () {
    String id(String tail) => 'a1000000-0000-4000-8000-${tail.padLeft(12, '0')}';
    late MockInquiryStore store;

    setUp(() => store = MockInquiryStore());

    TeacherInquiryDetail detail(String tail) => store.detailForTeacher(id(tail));

    test('…000a: 목록 조회와 무관하게 자기 상세 두 번째 조회에서 정리 완료', () {
      expect(detail('a').summary.refinementStatus, RefinementStatus.pending);
      for (var n = 0; n < 3; n++) {
        store.listForTeacher(page: 0, size: 50);
      }
      final second = detail('a');
      expect(second.summary.refinementStatus, RefinementStatus.refined);
      expect(second.timeline.last.stage, InquiryStage.refined);
      expect(store.refinementForTeacher(id('a')).facts, isNotEmpty);
    });

    test('…0003: F2 규칙 그대로(목록 두 번째 조회에 정리 완료)', () {
      expect(detail('3').summary.refinementStatus, RefinementStatus.pending);
      store.listForTeacher(page: 0, size: 50);
      store.listForTeacher(page: 0, size: 50);
      expect(detail('3').summary.refinementStatus, RefinementStatus.refined);
    });

    test('…0004: 다시 정리하기 → 다음 상세에서 정리 완료·번역본·정제 단계', () {
      expect(detail('4').retryAvailable, isTrue);
      store.retryForTeacher(id('4'));
      final next = detail('4');
      expect(next.summary.refinementStatus, RefinementStatus.refined);
      expect(next.timeline.last.stage, InquiryStage.refined);
      expect(store.refinementForTeacher(id('4')).title, isNotEmpty);
    });

    test('…0006: 다시 정리하기 → 다음 상세에서 원문 확인 필요·재시도 없음', () {
      store.retryForTeacher(id('6'));
      final next = detail('6');
      expect(next.summary.refinementStatus, RefinementStatus.needsOriginal);
      expect(next.retryAvailable, isFalse);
    });

    test('…0007: 재시도를 이미 씀', () {
      expect(detail('7').summary.refinementStatus, RefinementStatus.needsOriginal);
      expect(detail('7').retryAvailable, isFalse);
    });

    test('…0008: 정서 높음 · 분노·답답함', () {
      final r = store.refinementForTeacher(id('8'));
      expect(r.emotionLevel, EmotionLevel.high);
      expect(r.emotionLabels, [EmotionLabel.anger, EmotionLabel.frustration]);
    });

    test('…0009: 요청사항 없음 · 라벨 없음 · 낮음', () {
      final r = store.refinementForTeacher(id('9'));
      expect(r.requests, '');
      expect(r.emotionLabels, isEmpty);
      expect(r.emotionLevel, EmotionLevel.low);
    });

    test('담당 학급이 없는 교사(noclass)는 번역본·다시 정리하기 403', () async {
      final tokens = TokenStore()..accessToken = 'mock:noclass';
      final repo = MockTeacherInquiryRepository(tokens, store);
      for (final call in [
        () => repo.refinement(id('8')),
        () => repo.retryRefinement(id('4')),
      ]) {
        await expectLater(
          call(),
          throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 403)),
        );
      }
    });
  });

  testWidgets('refresh@ 계정: 문의 탭이 오류 없이 열린다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'refresh@damso.test');
    await tapTab(tester, '문의');
    expect(find.text('불러오지 못했습니다.'), findsNothing);
    expect(find.text('김하나 학생 문의'), findsWidgets);
  });
  group('F4 mock 저장소 (specs/004 research R11)', () {
    const answered = MockInquiryStore.answeredDemoId;
    const withFollowUp = MockInquiryStore.followUpDemoId;
    const followUp = MockInquiryStore.followUpDemoFollowUpId;
    const fresh = 'a1000000-0000-4000-8000-000000000008';
    late MockInquiryStore store;

    setUp(() => store = MockInquiryStore());

    test('답변 데모는 상세에 답변 1건', () {
      final d = store.detailForTeacher(answered);
      expect(d.answers, hasLength(1));
      expect(d.hasAnswers, isTrue);
      expect(d.summary.hasAnswer, isTrue); // 목록 hasAnswer 와 같은 값
    });

    test('재문의 데모는 마지막 답변보다 늦은 재문의 1건, 재문의 번역본·원문을 재문의 ID로 연다', () {
      final d = store.detailForTeacher(withFollowUp);
      expect(d.followUps.single.inquiryId, followUp);
      expect(d.followUps.single.submittedAt.isAfter(d.answers.last.sentAt), isTrue);
      expect(
        store.refinementForTeacher(followUp).requests,
        '금요일 안내 전에 중간 상황도 알려 주실 수 있는지 문의',
      );
      expect(store.contentForTeacher(followUp), contains('금요일에 안내 주신다고'));
    });

    test('전송하면 답변이 늘고 문의는 종료되지 않는다', () {
      store.sendAnswerForTeacher(fresh, '확인하겠습니다.', reviewed: true, lastSeenFollowUpId: null);
      final d = store.detailForTeacher(fresh);
      expect(d.answers.single.content, '확인하겠습니다.');
      expect(d.answers.single.reviewed, isTrue);
      expect(d.summary.stage, isNot(InquiryStage.answered));
      expect(d.summary.hasAnswer, isTrue);
    });

    test('답변 대기·답변 완료: 답변 뒤 재문의가 오면 다시 답변 대기(api-v0.11 needsAnswer)', () {
      TeacherInquirySummary summary(String id) => store
          .listForTeacher(page: 0, size: 100)
          .items
          .firstWhere((i) => i.inquiryId == id);

      expect(summary(answered).needsAnswer, isFalse);
      expect(summary(fresh).needsAnswer, isTrue);

      final withNewFollowUp = summary(withFollowUp);
      expect(withNewFollowUp.needsAnswer, isTrue);
      expect(withNewFollowUp.hasNewFollowUp, isTrue);
      expect(
        withNewFollowUp.lastFollowUpAt,
        store.detailForTeacher(withFollowUp).followUps.last.submittedAt,
      );

      store.sendAnswerForTeacher(fresh, '확인하겠습니다.', reviewed: true, lastSeenFollowUpId: null);
      expect(summary(fresh).needsAnswer, isFalse);
      store.sendAnswerForTeacher(
        withFollowUp,
        '확인하겠습니다.',
        reviewed: true,
        lastSeenFollowUpId: followUp,
      );
      expect(summary(withFollowUp).needsAnswer, isFalse);
    });

    test('answerStatus 로 서버처럼 거르고 totalElements 도 거른 결과 기준', () {
      final all = store.listForTeacher(page: 0, size: 100);
      final waiting = store.listForTeacher(
        page: 0,
        size: 100,
        answerStatus: AnswerStatus.waiting,
      );
      final done = store.listForTeacher(
        page: 0,
        size: 100,
        answerStatus: AnswerStatus.answered,
      );
      expect(waiting.items.every((i) => i.needsAnswer), isTrue);
      expect(done.items.every((i) => !i.needsAnswer), isTrue);
      expect(waiting.totalElements + done.totalElements, all.totalElements);
      expect(waiting.items.map((i) => i.inquiryId), contains(withFollowUp));
      expect(done.items.map((i) => i.inquiryId), [answered]);
    });

    test('본 재문의가 최신이 아니면 409 NEW_FOLLOW_UP, 답변은 저장되지 않는다', () {
      expect(
        () => store.sendAnswerForTeacher(
          withFollowUp,
          '확인하겠습니다.',
          reviewed: true,
          lastSeenFollowUpId: null,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.newFollowUp)),
      );
      expect(store.detailForTeacher(withFollowUp).answers, hasLength(1)); // 데모 답변 그대로
    });

    test('본문에 "재문의도착"이면 첫 전송 때 재문의가 와서 409, 새 재문의 ID 로 다시 보내면 성공', () {
      expect(
        () => store.sendAnswerForTeacher(
          fresh,
          '재문의도착 데모',
          reviewed: true,
          lastSeenFollowUpId: null,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.newFollowUp)),
      );
      final arrived = store.detailForTeacher(fresh).followUps.single;
      expect(store.refinementForTeacher(arrived.inquiryId).requests, isNotEmpty);
      store.sendAnswerForTeacher(
        fresh,
        '재문의도착 데모',
        reviewed: true,
        lastSeenFollowUpId: arrived.inquiryId,
      );
      final d = store.detailForTeacher(fresh);
      expect(d.answers, hasLength(1));
      expect(d.followUps, hasLength(1)); // 두 번째 전송에서는 더 오지 않는다
    });

    test('점검: 단어로 결과를 고른다', () {
      final suggest = store.reviewAnswerForTeacher(
        fresh,
        '어제 일은 확인해 보니 큰 문제는 아니었습니다. 확인되는 대로 연락드리겠습니다.',
      );
      expect(suggest.available, isTrue);
      expect(suggest.highlights, hasLength(2));
      expect(suggest.highlights.first.reason, '걱정을 가볍게 여기는 말로 읽힐 수 있어요.');

      expect(store.reviewAnswerForTeacher(fresh, '점검실패 데모').available, isFalse);
      final none = store.reviewAnswerForTeacher(fresh, '확인하겠습니다.');
      expect(none.available, isTrue);
      expect(none.highlights, isEmpty);
    });

    test('본문에 "전송실패"면 연결 오류, 답변은 늘지 않는다', () {
      expect(
        () => store.sendAnswerForTeacher(
          fresh,
          '전송실패 데모',
          reviewed: false,
          lastSeenFollowUpId: null,
        ),
        throwsA(isA<AppException>().having((e) => e.isNetworkError, 'network', isTrue)),
      );
      expect(store.detailForTeacher(fresh).answers, isEmpty);
    });

    test('공백만이면 400', () {
      expect(
        () => store.sendAnswerForTeacher(
          fresh,
          '   ',
          reviewed: false,
          lastSeenFollowUpId: null,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.invalidInput)),
      );
    });
  });

  testWidgets('refresh-teacher@ 계정: 접근 권한 갱신 뒤 답변 전송 성공(specs/004 US5-4, quickstart 23)', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'refresh-teacher@damso.test');
    expect(sessionOf(tester), const SignedIn(Role.teacher));
    await tapTab(tester, '문의');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final tile = find.byWidgetPredicate(
      (w) =>
          w is ListTile &&
          (w.title as Text).data == '친구와 다툰 일 관련 문의' &&
          ((w.subtitle as Text?)?.data ?? '').startsWith('이도윤'),
    );
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tapText(tester, '답변 작성');
    await tester.enterText(find.byType(TextField), '확인하겠습니다.');
    await tester.pump();
    await tapText(tester, '답변 점검');
    await tapText(tester, '직접 전송');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('답변을 보냈어요. 문의와 답변은 기록으로 보관돼요.'), findsOneWidget);
    expect(find.text('답변을 보내지 못했어요'), findsNothing);
    expect(sessionOf(tester), const SignedIn(Role.teacher));
  });

  /// spec FR-027 대조(specs/004 US5, T040). 401 갱신 자체는 F1 AuthInterceptor 가 맡는다.
  group('F4 시연', () {
    late MockInquiryStore store;

    setUp(() => store = MockInquiryStore());

    MockAnswerRepository answers(String token) =>
        MockAnswerRepository(TokenStore()..accessToken = token, store);

    test('담당 학급이 없는 교사(noclass)는 점검·전송 403(서버 문구), 저장되지 않는다', () async {
      final repo = answers('mock:noclass');
      const id = MockInquiryStore.answeredDemoId;
      for (final call in [
        () => repo.review(id, '확인하겠습니다.'),
        () => repo.send(id, '확인하겠습니다.', reviewed: true, lastSeenFollowUpId: null),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<AppException>()
                .having((e) => e.statusCode, 'status', 403)
                .having((e) => e.message, 'message', '담당 학급이 없습니다.'),
          ),
        );
      }
      expect(store.detailForTeacher(id).answers, hasLength(1)); // 데모 답변 그대로
    });

    test('담당 학급이 아닌 문의(남의 문의)는 점검·전송·상세 모두 거부', () async {
      final repo = answers('mock:teacher');
      const other = MockInquiryStore.forbiddenDemoId;
      for (final call in <Future<Object?> Function()>[
        () => repo.review(other, '확인하겠습니다.'),
        () => repo.send(other, '확인하겠습니다.', reviewed: true, lastSeenFollowUpId: null),
        () async => store.detailForTeacher(other),
      ]) {
        await expectLater(call(), throwsA(isA<AppException>()));
      }
    });

    test('점검 3종(제안 있음·없음·실패)과 전송 성공·실패를 재현한다', () async {
      final repo = answers('mock:teacher');
      const id = 'a1000000-0000-4000-8000-000000000008';
      expect(
        (await repo.review(id, '어제 일은 확인해 보니 큰 문제는 아니었습니다.')).highlights,
        isNotEmpty,
      );
      final none = await repo.review(id, '확인하겠습니다.');
      expect(none.available, isTrue);
      expect(none.highlights, isEmpty);
      expect((await repo.review(id, '점검실패')).available, isFalse);
      await expectLater(
        repo.send(id, '전송실패', reviewed: true, lastSeenFollowUpId: null),
        throwsA(isA<AppException>().having((e) => e.isNetworkError, 'network', isTrue)),
      );
      final sent = await repo.send(
        id,
        '확인하겠습니다.',
        reviewed: true,
        lastSeenFollowUpId: null,
      );
      expect(sent.inquiryId, id);
    });

    test('데모 문의 …000b·…000c 가 교사 목록에 답변 있음으로 보인다(답변 안 한 문의도 있음)', () {
      final items = store.listForTeacher(page: 0, size: 100).items;
      bool answered(String id) => items.firstWhere((i) => i.inquiryId == id).hasAnswer;
      expect(answered(MockInquiryStore.answeredDemoId), isTrue);
      expect(answered(MockInquiryStore.followUpDemoId), isTrue);
      expect(items.where((i) => !i.hasAnswer), isNotEmpty);
      expect(
        store.detailForTeacher(MockInquiryStore.followUpDemoId).followUps,
        isNotEmpty,
      );
    });
  });

  /// specs/006 quickstart 1~9 — 관리자 문의 현황 · 원문 열람 기록 실패 시연.
  group('F5 시연', () {
    Future<void> openStatus(WidgetTester tester, String email) async {
      useTallScreen(tester);
      await tester.pumpWidget(testApp());
      await login(tester, email);
      await tapTab(tester, '문의');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('admin@: 탭 셋 · 학급별 현황(0건 학급 포함) · 학급을 추가하면 새 학급이 0으로', (tester) async {
      await openStatus(tester, 'admin@damso.test');
      expect(find.text('문의 현황'), findsOneWidget);
      expect(find.text('3학년 2반 · 담임 연결됨'), findsOneWidget);
      expect(find.text('1학년 1반 · 담임 미연결'), findsOneWidget);
      expect(find.text('문의 0 · 답변 대기 0 · 교사 확인 0 · 답변 완료 0'), findsOneWidget);

      // 홈 탭 → 학급 추가(2학년 5반) → 문의 탭
      await tapTab(tester, '홈');
      await tapText(tester, '학급 추가');
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2학년').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('5반').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '학급 추가')); // 제목이 아니라 제출 버튼
      await tester.pumpAndSettle();
      expect(find.text('2학년 5반'), findsOneWidget); // 관리자 홈 목록

      await tapTab(tester, '문의');
      await tester.pumpAndSettle();
      expect(find.text('2학년 5반 · 담임 미연결'), findsOneWidget);
      expect(find.text('문의 0 · 답변 대기 0 · 교사 확인 0 · 답변 완료 0'), findsNWidgets(2));
    });

    testWidgets('teacher@: 원문 기록 실패 데모 → 원문 없이 서버 문구 + 다시 시도 → 원문(quickstart 9)', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(testApp());
      await login(tester, 'teacher@damso.test');
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      unawaited(router.push('/teacher/inquiries/${MockInquiryStore.contentLogFailDemoId}/general'));
      await tester.pumpAndSettle();

      await tapText(tester, '원문 보기');
      expect(find.text('요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('(mock) 데모 문의 원문입니다.'), findsNothing);

      await tapText(tester, '다시 시도');
      expect(find.text('(mock) 데모 문의 원문입니다.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // 원문 뒤 목록 새로 고침이 끝나게
    });

    testWidgets('refresh-admin@: 접근 권한 갱신 뒤 오류 없이 현황(quickstart 8)', (tester) async {
      await openStatus(tester, 'refresh-admin@damso.test');
      expect(sessionOf(tester), const SignedIn(Role.superAdmin));
      expect(find.text('학급별'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });
  });
}
