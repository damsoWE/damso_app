import 'dart:convert';
import 'dart:typed_data';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/features/admin/data/admin_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청을 기록하고 [respond]로 응답을 만드는 가짜 어댑터(F2·F3·F4 테스트와 같은 방식).
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

const _c32 = '3f6c1d2e-8a4b-4c1e-9f7a-2b5d8e9c0a11';
const _c33 = '7a2e4b9c-1d3f-4e8a-b6c5-0f9e8d7c6b22';

/// specs/006 contracts/api-usage.md — 문의 현황 경로와 해석·오류.
void main() {
  late _Adapter adapter;
  late AdminRepositoryImpl repo;

  setUp(() {
    adapter = _Adapter((_) => _json(200, {}));
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    repo = AdminRepositoryImpl(dio);
  });

  Matcher fallback() => throwsA(
    isA<AppException>().having((e) => e.message, 'message', AppException.fallbackMessage),
  );

  test('문의 현황: GET /admin/inquiry-status, 서버 순서·건수 그대로', () async {
    adapter.respond = (_) => _json(200, {
      'items': [
        {'classroomId': _c32, 'waiting': 2, 'confirmed': 1, 'answered': 5},
        {'classroomId': _c33, 'waiting': 0, 'confirmed': 0, 'answered': 0},
      ],
    });
    final items = await repo.inquiryStatus();

    final req = adapter.calls.single;
    expect(req.method, 'GET');
    expect(req.path, '/api/v1/admin/inquiry-status');
    expect(items.map((i) => i.classroomId), [_c32, _c33]);
    expect(
      items.map((i) => (i.waiting, i.confirmed, i.answered, i.total)),
      [(2, 1, 5, 8), (0, 0, 0, 0)],
    );
  });

  test('필드가 빠지면 일반 안내', () async {
    adapter.respond = (_) => _json(200, {
      'items': [
        {'classroomId': _c32, 'waiting': 2, 'confirmed': 1},
      ],
    });
    await expectLater(repo.inquiryStatus(), fallback());
  });

  test('건수가 음수거나 정수가 아니면 일반 안내', () async {
    for (final bad in <Object>[-1, 1.5, '3']) {
      adapter.respond = (_) => _json(200, {
        'items': [
          {'classroomId': _c32, 'waiting': bad, 'confirmed': 0, 'answered': 0},
        ],
      });
      await expectLater(repo.inquiryStatus(), fallback(), reason: '$bad');
    }
  });

  test('403 은 코드와 서버 문구 그대로', () async {
    adapter.respond = (_) => _json(403, {
      'code': 'FORBIDDEN',
      'message': '접근 권한이 없습니다.',
    });
    await expectLater(
      repo.inquiryStatus(),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', ErrorCodes.forbidden)
            .having((e) => e.message, 'message', '접근 권한이 없습니다.'),
      ),
    );
  });
}
