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
          'submittedAt': '2026-10-26T09:30:00Z',
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
    expect(page.hasMore, isTrue);
  });

  test('교사 원문: /content 경로', () async {
    adapter.respond = (_) => _json(200, {'inquiryId': _id, 'content': '원문'});
    expect(await TeacherInquiryRepositoryImpl(dio).content(_id), '원문');
    expect(adapter.calls.single.path, '/api/v1/teacher/inquiries/$_id/content');
  });
}
