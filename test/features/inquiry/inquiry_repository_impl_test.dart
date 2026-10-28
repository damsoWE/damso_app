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
        },
      ],
      'page': 1,
      'size': 20,
      'totalElements': 41,
    });
    final page = await TeacherInquiryRepositoryImpl(dio).list(page: 1);

    final req = adapter.calls.single;
    expect(req.path, '/api/v1/teacher/inquiries');
    expect(req.queryParameters, {'page': 1, 'size': 20});
    expect(page.items.single.refinementStatus, RefinementStatus.pending);
    expect(page.items.single.hasAnswer, isFalse);
    expect(page.items.single.lastAnsweredAt, isNull);
    expect(page.hasMore, isTrue);
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
}
