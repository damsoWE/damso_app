import 'dart:convert';
import 'dart:typed_data';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/features/reply/data/answer_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청을 기록하고 [respond]로 응답을 만드는 가짜 어댑터(F2·F3 테스트와 같은 방식).
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

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _id = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';

/// specs/004 contracts/api-usage.md — 점검·전송 경로와 해석·오류.
void main() {
  late _Adapter adapter;
  late Dio dio;
  late AnswerRepositoryImpl repo;

  setUp(() {
    adapter = _Adapter((_) => _json(200, {}));
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    repo = AnswerRepositoryImpl(dio);
  });

  test('점검: /answer-reviews 에 content 를 보내고 제안을 해석한다', () async {
    adapter.respond = (_) => _json(200, {
      'available': true,
      'contextUsed': true,
      'highlights': [
        {'excerpt': '문장 하나', 'reason': '이유 하나', 'suggestion': '제안 하나'},
        {'excerpt': '문장 둘', 'reason': '이유 둘', 'suggestion': '제안 둘'},
      ],
    });
    final r = await repo.review(_id, '본문');

    final req = adapter.calls.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/v1/teacher/inquiries/$_id/answer-reviews');
    expect(req.data, {'content': '본문'});
    expect(r.available, isTrue);
    expect(r.contextUsed, isTrue);
    expect(r.highlights.map((h) => h.excerpt), ['문장 하나', '문장 둘']);
    expect(r.highlights.first.reason, '이유 하나');
    expect(r.highlights.first.suggestion, '제안 하나');
  });

  test('점검 불가는 오류가 아니라 available=false', () async {
    adapter.respond = (_) => _json(200, {'available': false, 'contextUsed': false, 'highlights': []});
    final r = await repo.review(_id, '본문');
    expect(r.available, isFalse);
    expect(r.contextUsed, isFalse);
    expect(r.highlights, isEmpty);
  });

  test('전송: /answers 에 content·reviewed·lastSeenFollowUpId 를 보내고 결과를 해석한다', () async {
    adapter.respond = (_) => _json(201, {
      'answerId': 'e0000000-0000-4000-8000-000000000001',
      'inquiryId': _id,
      'sentAt': '2026-10-28T10:00:00Z',
    });
    final sent = await repo.send(
      _id,
      '본문',
      reviewed: true,
      lastSeenFollowUpId: 'f0000000-0000-4000-8000-000000000001',
    );

    final req = adapter.calls.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/v1/teacher/inquiries/$_id/answers');
    expect(req.data, {
      'content': '본문',
      'reviewed': true,
      'lastSeenFollowUpId': 'f0000000-0000-4000-8000-000000000001',
    });
    expect(sent.answerId, 'e0000000-0000-4000-8000-000000000001');
    expect(sent.inquiryId, _id);
    expect(sent.sentAt, DateTime.parse('2026-10-28T10:00:00Z'));
  });

  test('재문의가 없으면 lastSeenFollowUpId 키를 null 로 보낸다(빠지면 400)', () async {
    adapter.respond = (_) => _json(201, {
      'answerId': 'e0000000-0000-4000-8000-000000000001',
      'inquiryId': _id,
      'sentAt': '2026-10-28T10:00:00Z',
    });
    await repo.send(_id, '본문', reviewed: true, lastSeenFollowUpId: null);

    final data = adapter.calls.single.data as Map;
    expect(data.containsKey('lastSeenFollowUpId'), isTrue);
    expect(data['lastSeenFollowUpId'], isNull);
  });

  test('409 NEW_FOLLOW_UP 은 코드와 서버 문구 그대로', () async {
    adapter.respond = (_) => _json(409, {
      'code': 'NEW_FOLLOW_UP',
      'message': '확인하지 않은 재문의가 있습니다. 스레드를 다시 불러온 뒤 보내 주세요.',
    });
    await expectLater(
      repo.send(_id, '본문', reviewed: true, lastSeenFollowUpId: null),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', ErrorCodes.newFollowUp)
            .having(
              (e) => e.message,
              'message',
              '확인하지 않은 재문의가 있습니다. 스레드를 다시 불러온 뒤 보내 주세요.',
            ),
      ),
    );
  });

  test('409 THREAD_CLOSED 는 코드와 서버 문구 그대로', () async {
    adapter.respond = (_) => _json(409, {
      'code': 'THREAD_CLOSED',
      'message': '이미 종료된 문의입니다.',
    });
    await expectLater(
      repo.send(_id, '본문', reviewed: false, lastSeenFollowUpId: null),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', ErrorCodes.threadClosed)
            .having((e) => e.message, 'message', '이미 종료된 문의입니다.'),
      ),
    );
  });

  test('400 INVALID_INPUT 의 fieldErrors.content', () async {
    adapter.respond = (_) => _json(400, {
      'code': 'INVALID_INPUT',
      'message': '입력값이 올바르지 않습니다.',
      'fieldErrors': [
        {'field': 'content', 'reason': '최대 2000자입니다'},
      ],
    });
    await expectLater(
      repo.review(_id, '본문'),
      throwsA(
        isA<AppException>().having(
          (e) => e.fieldErrors['content'],
          'fieldErrors.content',
          '최대 2000자입니다',
        ),
      ),
    );
  });

  test('응답 형식이 틀리면 일반 안내', () async {
    adapter.respond = (_) => _json(201, {'answerId': 'x'});
    await expectLater(
      repo.send(_id, '본문', reviewed: false, lastSeenFollowUpId: null),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          AppException.fallbackMessage,
        ),
      ),
    );
  });
}
