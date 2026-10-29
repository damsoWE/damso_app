import 'dart:convert';
import 'dart:typed_data';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/inquiry/data/parent_inquiry_repository_impl.dart';
import 'package:damso_app/features/inquiry/data/teacher_inquiry_repository_impl.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청을 기록하고 [respond]로 응답을 만드는 가짜 어댑터.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  ResponseBody Function(RequestOptions) respond;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  int status,
  Object body, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

const _id = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';
const _student = '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51';

void main() {
  late _Adapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _Adapter((_) => _json(200, {}));
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  });

  Future<InquirySubmitted> submit() => ParentInquiryRepositoryImpl(dio).submit(
    studentId: _student,
    content: '본문',
    idempotencyKey: 'key-1',
  );

  test('제출: Idempotency-Key 헤더와 본문을 보내고 안내·번호 코드를 해석한다', () async {
    adapter.respond = (_) => _json(201, {
      'inquiryId': _id,
      'urgent': true,
      'stage': 'DELIVERED',
      'submittedAt': '2026-10-26T09:30:00Z',
      'notices': ['URGENT_DELIVERED'],
      'hotlines': ['SUICIDE_PREVENTION_109'],
    });
    final result = await submit();

    final req = adapter.calls.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/v1/parent/inquiries');
    expect(req.headers['Idempotency-Key'], 'key-1');
    expect(req.data, {'studentId': _student, 'content': '본문'});
    expect(result.urgent, isTrue);
    expect(result.stage, InquiryStage.delivered);
    final outcome = result.outcome;
    expect(outcome, isA<UrgentNotice>());
    expect((outcome as UrgentNotice).hotlines, [Hotline.suicidePrevention]);
  });

  test('모르는 단계 값이면 일반 안내(AppException)', () async {
    adapter.respond = (_) => _json(201, {
      'inquiryId': _id,
      'urgent': false,
      'stage': 'SOMETHING_NEW',
      'submittedAt': '2026-10-26T09:30:00Z',
      'notices': ['RECEIVED'],
      'hotlines': <String>[],
    });
    await expectLater(
      submit(),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          AppException.fallbackMessage,
        ),
      ),
    );
  });

  test('1분 제한: 429 Retry-After → retryAfter', () async {
    adapter.respond = (_) => _json(
      429,
      {'code': 'TOO_MANY_ATTEMPTS', 'message': '잠시 후 다시 시도해 주세요.'},
      headers: {
        'retry-after': ['42'],
      },
    );
    await expectLater(
      submit(),
      throwsA(
        isA<AppException>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(seconds: 42),
        ),
      ),
    );
  });

  test('교사 목록: page·size 쿼리와 페이지 해석', () async {
    adapter.respond = (_) => _json(200, {
      'items': [
        {
          'inquiryId': _id,
          'studentId': _student,
          'studentName': '김하나',
          'urgent': false,
          'title': '정리 중',
          'stage': 'RECEIVED',
          'refinementStatus': 'PENDING',
          'threatFlagged': false,
          'threadThreatFlagged': false,
          'submittedAt': '2026-10-26T09:30:00Z',
          'hasAnswer': false,
          'lastAnsweredAt': null,
          'lastFollowUpAt': null,
          'needsAnswer': true,
        },
      ],
      'page': 1,
      'size': 20,
      'totalElements': 41,
    });
    final page = await TeacherInquiryRepositoryImpl(dio).list(page: 1);

    final req = adapter.calls.single;
    expect(req.path, '/api/v1/teacher/inquiries');
    expect(req.queryParameters, {'page': 1, 'size': 20}); // 거르지 않으면 answerStatus 없음
    expect(page.items.single.refinementStatus, RefinementStatus.pending);
    expect(page.items.single.hasAnswer, isFalse);
    expect(page.items.single.lastAnsweredAt, isNull);
    expect(page.items.single.needsAnswer, isTrue);
    expect(page.items.single.lastFollowUpAt, isNull);
    expect(page.hasMore, isTrue);
  });

  test('교사 목록: answerStatus 쿼리, 재문의 시각·needsAnswer 는 서버 값(api-v0.11)', () async {
    adapter.respond = (_) => _json(200, {
      'items': [
        {
          'inquiryId': _id,
          'studentId': _student,
          'studentName': '김하나',
          'urgent': false,
          'title': '친구 관계 관련 문의',
          'stage': 'TEACHER_CONFIRMED',
          'refinementStatus': 'REFINED',
          'threatFlagged': false,
          'threadThreatFlagged': false,
          'submittedAt': '2026-10-26T09:30:00Z',
          'hasAnswer': true,
          'lastAnsweredAt': '2026-10-27T08:00:00Z',
          'lastFollowUpAt': '2026-10-27T09:00:00Z',
          'needsAnswer': true,
        },
      ],
      'page': 0,
      'size': 20,
      'totalElements': 1,
    });
    final page = await TeacherInquiryRepositoryImpl(dio).list(answerStatus: AnswerStatus.waiting);

    expect(adapter.calls.single.queryParameters, {
      'page': 0,
      'size': 20,
      'answerStatus': 'WAITING',
    });
    final item = page.items.single;
    expect(item.needsAnswer, isTrue);
    expect(item.hasNewFollowUp, isTrue);
    expect(item.lastFollowUpAt, DateTime.parse('2026-10-27T09:00:00Z'));
  });

  test('교사 목록: needsAnswer 가 없으면 형식 오류(일반 안내)', () async {
    adapter.respond = (_) => _json(200, {
      'items': [
        {
          'inquiryId': _id,
          'studentId': _student,
          'studentName': '김하나',
          'urgent': false,
          'title': '정리 중',
          'stage': 'RECEIVED',
          'refinementStatus': 'PENDING',
          'submittedAt': '2026-10-26T09:30:00Z',
          'hasAnswer': false,
          'lastAnsweredAt': null,
          'lastFollowUpAt': null,
        },
      ],
      'page': 0,
      'size': 20,
      'totalElements': 1,
    });
    await expectLater(
      TeacherInquiryRepositoryImpl(dio).list(),
      throwsA(
        isA<AppException>().having((e) => e.message, 'message', AppException.fallbackMessage),
      ),
    );
  });

  group('답변 여부(api-v0.7)', () {
    Map<String, dynamic> parentItem({Object? hasAnswer = false}) => {
      'inquiryId': _id,
      'studentId': _student,
      'studentName': '김하나',
      'urgent': false,
      'stage': 'TEACHER_CONFIRMED',
      'submittedAt': '2026-10-26T09:30:00Z',
      'hasAnswer': ?hasAnswer,
      'lastAnsweredAt': hasAnswer == true ? '2026-10-27T08:00:00Z' : null,
    };

    test('학부모 목록: hasAnswer·lastAnsweredAt 을 읽는다', () async {
      adapter.respond = (_) => _json(200, [parentItem(hasAnswer: true)]);
      final item = (await ParentInquiryRepositoryImpl(dio).list()).single;

      expect(item.hasAnswer, isTrue);
      expect(item.lastAnsweredAt, DateTime.parse('2026-10-27T08:00:00Z'));
      expect(item.stage, InquiryStage.teacherConfirmed);
    });

    test('목록에 hasAnswer 가 없으면 일반 안내(AppException)', () async {
      adapter.respond = (_) => _json(200, [parentItem(hasAnswer: null)]);
      await expectLater(
        ParentInquiryRepositoryImpl(dio).list(),
        throwsA(isA<AppException>()),
      );
    });

    test('학부모 상세: answers 로 답변 여부와 마지막 답변 시각을 정한다', () async {
      adapter.respond = (_) => _json(200, {
        'inquiryId': _id,
        'studentId': _student,
        'studentName': '김하나',
        'content': '본문',
        'urgent': false,
        'stage': 'TEACHER_CONFIRMED',
        'submittedAt': '2026-10-26T09:30:00Z',
        'timeline': [
          {'stage': 'RECEIVED', 'occurredAt': '2026-10-26T09:30:00Z'},
        ],
        'notices': ['RECEIVED'],
        'hotlines': <String>[],
        'followUps': <Object>[],
        'answers': [
          {
            'answerId': 'a1',
            'content': '답변1',
            'reviewed': false,
            'sentAt': '2026-10-27T08:00:00Z',
          },
          {
            'answerId': 'a2',
            'content': '답변2',
            'reviewed': true,
            'sentAt': '2026-10-28T08:00:00Z',
          },
        ],
      });
      final d = await ParentInquiryRepositoryImpl(dio).detail(_id);

      expect(d.summary.hasAnswer, isTrue);
      expect(d.summary.lastAnsweredAt, DateTime.parse('2026-10-28T08:00:00Z'));
    });

    test('교사 상세: answers 가 비면 답변 없음', () async {
      adapter.respond = (_) => _json(200, {
        'inquiryId': _id,
        'studentId': _student,
        'studentName': '김하나',
        'urgent': false,
        'title': '정리 중',
        'stage': 'RECEIVED',
        'refinementStatus': 'PENDING',
        'retryAvailable': false,
        'threatFlagged': false,
        'submittedAt': '2026-10-27T09:00:00Z',
        'timeline': [
          {'stage': 'RECEIVED', 'occurredAt': '2026-10-27T09:00:00Z'},
        ],
        'followUps': <Object>[],
        'answers': <Object>[],
      });
      final d = await TeacherInquiryRepositoryImpl(dio).detail(_id);

      expect(d.summary.hasAnswer, isFalse);
      expect(d.summary.lastAnsweredAt, isNull);
    });
  });

  test('교사 원문: /content 경로', () async {
    adapter.respond = (_) => _json(200, {'inquiryId': _id, 'content': '원문'});
    expect(await TeacherInquiryRepositoryImpl(dio).content(_id), '원문');
    expect(adapter.calls.single.path, '/api/v1/teacher/inquiries/$_id/content');
  });

  group('F3', () {
    Map<String, dynamic> refinementBody({
      String requests = '이번 주 안 회신 요청',
      Object? level = 'HIGH',
      List<Object?> labels = const ['ANGER'],
    }) => {
      'inquiryId': _id,
      'title': '친구 관계 관련 문의',
      'facts': '학생이 다쳐 귀가했다고 전했어요.',
      'requests': requests,
      'emotionLevel': level,
      'emotionLabels': labels,
      'refinedAt': '2026-10-27T09:30:00Z',
    };

    test('상세: retryAvailable 을 읽는다', () async {
      adapter.respond = (_) => _json(200, {
        'inquiryId': _id,
        'studentId': _student,
        'studentName': '김하나',
        'urgent': false,
        'title': '원문 확인 필요',
        'stage': 'RECEIVED',
        'refinementStatus': 'NEEDS_ORIGINAL',
        'retryAvailable': true,
        'submittedAt': '2026-10-27T09:00:00Z',
        'timeline': [
          {'stage': 'RECEIVED', 'occurredAt': '2026-10-27T09:00:00Z'},
        ],
      });
      final d = await TeacherInquiryRepositoryImpl(dio).detail(_id);
      expect(d.retryAvailable, isTrue);
      expect(d.summary.refinementStatus, RefinementStatus.needsOriginal);
    });

    test('번역본: /refinement 경로와 해석', () async {
      adapter.respond = (_) => _json(200, refinementBody());
      final r = await TeacherInquiryRepositoryImpl(dio).refinement(_id);

      expect(adapter.calls.single.path, '/api/v1/teacher/inquiries/$_id/refinement');
      expect(adapter.calls.single.method, 'GET');
      expect(r.title, '친구 관계 관련 문의');
      expect(r.facts, '학생이 다쳐 귀가했다고 전했어요.');
      expect(r.requests, '이번 주 안 회신 요청');
      expect(r.emotionLevel, EmotionLevel.high);
      expect(r.emotionLabels, [EmotionLabel.anger]);
      expect(r.refinedAt, DateTime.parse('2026-10-27T09:30:00Z'));
    });

    test('번역본: 요청사항 빈 문자열은 그대로', () async {
      adapter.respond = (_) => _json(200, refinementBody(requests: '', labels: []));
      final r = await TeacherInquiryRepositoryImpl(dio).refinement(_id);
      expect(r.requests, '');
      expect(r.emotionLabels, isEmpty);
    });

    test('번역본: 모르는 정서강도는 null, 라벨은 모르는 값·중복을 빼고 앞에서 2개', () async {
      adapter.respond = (_) => _json(
        200,
        refinementBody(
          level: 'EXTREME',
          labels: ['ANGER', 'UNKNOWN', 'ANGER', 'WORRY', 'SADNESS'],
        ),
      );
      final r = await TeacherInquiryRepositoryImpl(dio).refinement(_id);
      expect(r.emotionLevel, isNull);
      expect(r.emotionLabels, [EmotionLabel.anger, EmotionLabel.worry]);
    });

    test('다시 정리하기: POST /refinement/retry, 202 → 정리 상태', () async {
      adapter.respond = (_) =>
          _json(202, {'inquiryId': _id, 'refinementStatus': 'PENDING'});
      final status = await TeacherInquiryRepositoryImpl(dio).retryRefinement(_id);

      final req = adapter.calls.single;
      expect(req.path, '/api/v1/teacher/inquiries/$_id/refinement/retry');
      expect(req.method, 'POST');
      expect(req.data, isNull);
      expect(status, RefinementStatus.pending);
    });

    for (final code in ['REFINEMENT_NOT_READY', 'REFINEMENT_RETRY_UNAVAILABLE']) {
      test('409 $code → AppException.code', () async {
        adapter.respond = (_) =>
            _json(409, {'code': code, 'message': '서버 안내'});
        final repo = TeacherInquiryRepositoryImpl(dio);
        final call = code == 'REFINEMENT_NOT_READY'
            ? repo.refinement(_id)
            : repo.retryRefinement(_id);
        await expectLater(
          call,
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', '서버 안내'),
          ),
        );
      });
    }
  });
  group('학부모 F4 상세', () {
    Map<String, dynamic> detailJson({List<Object?>? followUps, List<Object?>? answers}) => {
      'inquiryId': _id,
      'studentId': _student,
      'studentName': '김하나',
      'content': '처음 문의',
      'urgent': false,
      'stage': 'TEACHER_CONFIRMED',
      'submittedAt': '2026-10-26T09:30:00Z',
      'timeline': [
        {'stage': 'RECEIVED', 'occurredAt': '2026-10-26T09:30:00Z'},
      ],
      'notices': ['RECEIVED'],
      'hotlines': <String>[],
      'followUps': followUps ?? <Object>[],
      'answers': answers ?? <Object>[],
    };

    Map<String, dynamic> followUp(String at, {String content = '재문의'}) => {
      'inquiryId': 'f-$at',
      'content': content,
      'urgent': true,
      'stage': 'DELIVERED',
      'submittedAt': at,
      'notices': ['URGENT_DELIVERED'],
      'hotlines': ['SUICIDE_PREVENTION_109'],
    };

    Map<String, dynamic> answer(String at, {String content = '답변'}) => {
      'answerId': 'a-$at',
      'content': content,
      'reviewed': true,
      'sentAt': at,
    };

    test('content·followUps·answers 를 해석한다(reviewed 는 무시)', () async {
      adapter.respond = (_) => _json(
        200,
        detailJson(
          followUps: [followUp('2026-10-28T09:00:00Z')],
          answers: [answer('2026-10-27T08:00:00Z')],
        ),
      );
      final d = await ParentInquiryRepositoryImpl(dio).detail(_id);

      expect(d.content, '처음 문의');
      final f = d.followUps.single;
      expect(f.inquiryId, 'f-2026-10-28T09:00:00Z');
      expect(f.content, '재문의');
      expect(f.urgent, isTrue);
      expect(f.stage, InquiryStage.delivered);
      expect(f.submittedAt, DateTime.parse('2026-10-28T09:00:00Z'));
      expect(f.notices, [Notice.urgentDelivered]);
      expect(f.hotlines, [Hotline.suicidePrevention]);
      final a = d.answers.single;
      expect(a.answerId, 'a-2026-10-27T08:00:00Z');
      expect(a.content, '답변');
      expect(a.sentAt, DateTime.parse('2026-10-27T08:00:00Z'));
    });

    test('thread: 시각 오름차순으로 처음 문의·답변·재문의를 섞는다', () async {
      adapter.respond = (_) => _json(
        200,
        detailJson(
          followUps: [followUp('2026-10-29T09:00:00Z')],
          answers: [answer('2026-10-27T08:00:00Z')],
        ),
      );
      final thread = (await ParentInquiryRepositoryImpl(dio).detail(_id)).thread;

      expect(thread.map((i) => i.runtimeType), [RootItem, AnswerItem, FollowUpItem]);
    });

    test('thread: 시각이 같으면 입력 순서(처음 문의 → 재문의 → 답변)', () async {
      const at = '2026-10-26T09:30:00Z';
      adapter.respond = (_) =>
          _json(200, detailJson(followUps: [followUp(at)], answers: [answer(at)]));
      final thread = (await ParentInquiryRepositoryImpl(dio).detail(_id)).thread;

      expect(thread.map((i) => i.runtimeType), [RootItem, FollowUpItem, AnswerItem]);
    });

    test('followUps·answers 가 모두 비면 thread 는 RootItem 하나', () async {
      adapter.respond = (_) => _json(200, detailJson());
      final thread = (await ParentInquiryRepositoryImpl(dio).detail(_id)).thread;

      expect(thread, hasLength(1));
      expect((thread.single as RootItem).content, '처음 문의');
    });

    test('필드가 없으면 일반 안내(AppException)', () async {
      for (final missing in ['content', 'followUps', 'answers']) {
        adapter.respond = (_) => _json(200, detailJson()..remove(missing));
        await expectLater(
          ParentInquiryRepositoryImpl(dio).detail(_id),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              AppException.fallbackMessage,
            ),
          ),
          reason: missing,
        );
      }
    });
  });

  group('재문의 제출', () {
    Future<FollowUpSubmitted> send() => ParentInquiryRepositoryImpl(dio).submitFollowUp(
      inquiryId: 'r1',
      content: '본문',
      idempotencyKey: 'k1',
    );

    test('POST follow-ups: 키 헤더·본문을 보내고 결과를 해석한다', () async {
      adapter.respond = (_) => _json(201, {
        'inquiryId': 'f1',
        'threadRootId': 'r1',
        'urgent': true,
        'submittedAt': '2026-10-29T09:00:00Z',
        'notices': ['URGENT_DELIVERED'],
        'hotlines': ['SUICIDE_PREVENTION_109'],
      });
      final result = await send();

      final req = adapter.calls.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/v1/parent/inquiries/r1/follow-ups');
      expect(req.headers['Idempotency-Key'], 'k1');
      expect(req.data, {'content': '본문'});
      expect(result.inquiryId, 'f1');
      expect(result.threadRootId, 'r1');
      expect(result.urgent, isTrue);
      expect(result.submittedAt, DateTime.parse('2026-10-29T09:00:00Z'));
      expect(result.outcome, isA<UrgentNotice>());
    });

    test('409 는 서버 코드를 그대로 전한다', () async {
      for (final code in ['NO_HOMEROOM_TEACHER', 'CONFLICT', 'THREAD_CLOSED']) {
        adapter.respond = (_) => _json(409, {'code': code, 'message': '안내 $code'});
        await expectLater(
          send(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', '안내 $code')
                .having((e) => e.statusCode, 'status', 409),
          ),
        );
      }
    });

    test('429 + Retry-After → retryAfter', () async {
      adapter.respond = (_) => _json(
        429,
        {'code': 'RATE_LIMITED', 'message': '잠시 후'},
        headers: {'retry-after': ['30']},
      );
      await expectLater(
        send(),
        throwsA(
          isA<AppException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('400 fieldErrors → fieldErrors[content]', () async {
      adapter.respond = (_) => _json(400, {
        'code': 'INVALID_INPUT',
        'message': '입력 오류',
        'fieldErrors': [
          {'field': 'content', 'reason': '최대 2000자입니다'},
        ],
      });
      await expectLater(
        send(),
        throwsA(
          isA<AppException>().having(
            (e) => e.fieldErrors['content'],
            'content',
            '최대 2000자입니다',
          ),
        ),
      );
    });
  });

  group('F4 상세 (specs/004)', () {
    Map<String, dynamic> detailBody({Object? followUps, Object? answers, String fuStage = 'REFINING'}) => {
      'inquiryId': _id,
      'studentId': _student,
      'studentName': '김하나',
      'urgent': false,
      'title': '친구 관계 관련 문의',
      'stage': 'TEACHER_CONFIRMED',
      'refinementStatus': 'REFINED',
      'retryAvailable': false,
      'threatFlagged': true,
      'submittedAt': '2026-10-27T09:00:00Z',
      'timeline': [
        {'stage': 'RECEIVED', 'occurredAt': '2026-10-27T09:00:00Z'},
      ],
      'followUps': followUps ?? [
        {
          'inquiryId': 'f0000000-0000-4000-8000-000000000001',
          'urgent': false,
          'title': '중간 안내 요청',
          'stage': fuStage,
          'threatFlagged': false,
          'submittedAt': '2026-10-28T09:10:00Z',
        },
      ],
      'answers': answers ?? [
        {
          'answerId': 'e0000000-0000-4000-8000-000000000001',
          'content': '확인 후 안내드리겠습니다.',
          'reviewed': true,
          'sentAt': '2026-10-27T14:05:00Z',
        },
      ],
    };

    test('재문의·답변을 시간순 그대로 해석한다(threatFlagged 는 무시)', () async {
      adapter.respond = (_) => _json(200, detailBody());
      final d = await TeacherInquiryRepositoryImpl(dio).detail(_id);

      expect(d.followUps.single.inquiryId, 'f0000000-0000-4000-8000-000000000001');
      expect(d.followUps.single.stage, InquiryStage.refined);
      expect(d.followUps.single.submittedAt, DateTime.parse('2026-10-28T09:10:00Z'));
      expect(d.answers.single.content, '확인 후 안내드리겠습니다.');
      expect(d.answers.single.reviewed, isTrue);
      expect(d.hasAnswers, isTrue);
    });

    test('빈 목록이면 빈 목록', () async {
      adapter.respond = (_) => _json(200, detailBody(followUps: [], answers: []));
      final d = await TeacherInquiryRepositoryImpl(dio).detail(_id);
      expect(d.followUps, isEmpty);
      expect(d.hasAnswers, isFalse);
    });

    test('재문의 단계가 모르는 값이면 일반 안내(AppException)', () async {
      adapter.respond = (_) => _json(200, detailBody(fuStage: 'UNKNOWN'));
      await expectLater(
        TeacherInquiryRepositoryImpl(dio).detail(_id),
        throwsA(
          isA<AppException>().having((e) => e.message, 'message', AppException.fallbackMessage),
        ),
      );
    });
  });
}
