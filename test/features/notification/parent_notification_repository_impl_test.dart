import 'dart:convert';
import 'dart:typed_data';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/notification/data/parent_notification_repository_impl.dart';
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

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late _Adapter adapter;
  late ParentNotificationRepositoryImpl repo;

  setUp(() {
    adapter = _Adapter((_) => _json(200, {'answerNotifyEnabled': true}));
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    repo = ParentNotificationRepositoryImpl(dio);
  });

  test('getSettings → GET 후 answerNotifyEnabled 해석', () async {
    adapter.respond = (_) => _json(200, {'answerNotifyEnabled': false});
    final s = await repo.getSettings();

    final req = adapter.calls.single;
    expect(req.method, 'GET');
    expect(req.path, '/api/v1/parent/notification-settings');
    expect(s.answerNotifyEnabled, isFalse);
  });

  test('saveSettings(false) → PUT body {"answerNotifyEnabled":false}', () async {
    adapter.respond = (_) => _json(200, {'answerNotifyEnabled': false});
    final s = await repo.saveSettings(false);

    final req = adapter.calls.single;
    expect(req.method, 'PUT');
    expect(req.path, '/api/v1/parent/notification-settings');
    expect(req.data, {'answerNotifyEnabled': false});
    expect(s.answerNotifyEnabled, isFalse);
  });

  test('400 → AppException(서버 안내)', () async {
    adapter.respond = (_) => _json(400, {'code': 'INVALID_INPUT', 'message': '입력 오류'});
    await expectLater(
      repo.saveSettings(true),
      throwsA(
        isA<AppException>()
            .having((e) => e.message, 'message', '입력 오류')
            .having((e) => e.statusCode, 'status', 400),
      ),
    );
  });

  test('필드가 없으면 일반 안내', () async {
    adapter.respond = (_) => _json(200, <String, Object>{});
    await expectLater(
      repo.getSettings(),
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
