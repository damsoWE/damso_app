import 'dart:convert';
import 'dart:typed_data';

import 'package:damso_app/core/network/auth_interceptor.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 패키지 없이 직접 만든 가짜 어댑터. 요청마다 [handler] 가 응답을 만든다.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final calls = <RequestOptions>[];

  int countPath(String path) => calls.where((c) => c.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _protected = '/api/v1/parent/children';
const _refresh = '/api/v1/auth/token/refresh';
const _unauthorized = {'code': 'UNAUTHORIZED', 'message': '인증이 필요합니다.'};

void main() {
  late TokenStore tokens;
  late Dio dio;
  late _FakeAdapter adapter;
  late int expiredCalls;

  /// 기본 서버: 보호 경로는 새 토큰일 때만 200, 갱신은 지연 후 새 토큰 발급.
  Future<ResponseBody> server(RequestOptions o) async {
    if (o.path == _refresh) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _json(200, {
        'accessToken': 'at-new',
        'accessTokenExpiresInSeconds': 900,
        'refreshToken': 'rt-2',
        'refreshTokenExpiresInSeconds': 1209600,
        'role': 'PARENT',
      });
    }
    if (o.headers['Authorization'] == 'Bearer at-new') return _json(200, []);
    return _json(401, _unauthorized);
  }

  void setUpDio(Future<ResponseBody> Function(RequestOptions) handler) {
    adapter = _FakeAdapter(handler);
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(dio, tokens, onSessionExpired: () => expiredCalls++),
    );
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'refresh_token': 'rt-1'});
    tokens = TokenStore()..accessToken = 'at-old';
    expiredCalls = 0;
    setUpDio(server);
  });

  test('accessToken 이 있으면 Authorization 헤더를 주입한다', () async {
    tokens.accessToken = 'at-new';
    await dio.get<dynamic>(_protected);
    expect(adapter.calls.single.headers['Authorization'], 'Bearer at-new');
  });

  test('401 → 갱신 1회 → 새 토큰 저장 → 원 요청 1회 재시도', () async {
    final res = await dio.get<dynamic>(_protected);

    expect(res.statusCode, 200);
    expect(adapter.countPath(_refresh), 1);
    final refreshCall = adapter.calls.firstWhere((c) => c.path == _refresh);
    expect(refreshCall.data, {'refreshToken': 'rt-1'});
    expect(adapter.countPath(_protected), 2);
    expect(tokens.accessToken, 'at-new');
    expect(await tokens.readRefreshToken(), 'rt-2');
    expect(expiredCalls, 0);
  });

  test('동시 401 3건에도 갱신은 1회, 각 요청은 1회만 재시도', () async {
    final results = await Future.wait([
      dio.get<dynamic>(_protected),
      dio.get<dynamic>(_protected),
      dio.get<dynamic>(_protected),
    ]);

    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(adapter.countPath(_refresh), 1);
    expect(adapter.countPath(_protected), 6);
  });

  test('공개 경로의 401 은 갱신하지 않고 헤더도 넣지 않는다', () async {
    setUpDio((o) async => _json(401, _unauthorized));
    const publicPaths = [
      '/api/v1/auth/invite-codes/verify',
      '/api/v1/auth/login',
      '/api/v1/auth/signup',
      '/api/v1/auth/signup/verify',
      '/api/v1/auth/signup/resend',
      '/api/v1/auth/password-reset',
      '/api/v1/auth/password-reset/verify',
      '/api/v1/auth/password-reset/confirm',
      '/api/v1/auth/token/refresh',
    ];
    for (final path in publicPaths) {
      await expectLater(
        dio.post<dynamic>(path),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
        reason: path,
      );
    }
    expect(adapter.calls.length, publicPaths.length); // 갱신 호출 없음
    expect(
      adapter.calls.map((c) => c.headers['Authorization']),
      everyElement(isNull),
    );
    expect(expiredCalls, 0);
  });

  test('INVALID_CREDENTIALS 401(탈퇴 비밀번호 불일치)은 갱신하지 않는다', () async {
    setUpDio(
      (o) async => _json(401, {
        'code': 'INVALID_CREDENTIALS',
        'message': '이메일 또는 비밀번호가 올바르지 않습니다.',
      }),
    );
    await expectLater(
      dio.post<dynamic>('/api/v1/me/withdrawal'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.countPath(_refresh), 0);
    expect(tokens.accessToken, 'at-old');
    expect(expiredCalls, 0);
  });

  test('갱신이 401 이면 토큰을 지우고 onSessionExpired 를 1회 호출한다', () async {
    setUpDio((o) async => _json(401, _unauthorized));
    await expectLater(
      dio.get<dynamic>(_protected),
      throwsA(
        isA<DioException>().having((e) => e.response?.statusCode, 'status', 401),
      ),
    );
    expect(adapter.countPath(_refresh), 1);
    expect(tokens.accessToken, isNull);
    expect(await tokens.readRefreshToken(), isNull);
    expect(expiredCalls, 1);
  });

  test('재시도한 요청이 또 401 이면 두 번째 갱신은 없다', () async {
    setUpDio((o) async {
      if (o.path == _refresh) return server(o);
      return _json(401, _unauthorized);
    });
    await expectLater(dio.get<dynamic>(_protected), throwsA(isA<DioException>()));
    expect(adapter.countPath(_refresh), 1);
    expect(adapter.countPath(_protected), 2);
  });

  test('저장된 갱신 토큰이 없으면 갱신 호출 없이 onSessionExpired', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(dio.get<dynamic>(_protected), throwsA(isA<DioException>()));
    expect(adapter.countPath(_refresh), 0);
    expect(tokens.accessToken, isNull);
    expect(expiredCalls, 1);
  });

  test('갱신 중 네트워크 오류면 토큰을 지우지 않고 네트워크 오류를 넘긴다', () async {
    setUpDio((o) async {
      if (o.path == _refresh) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
      }
      return _json(401, _unauthorized);
    });
    await expectLater(
      dio.get<dynamic>(_protected),
      throwsA(
        isA<DioException>().having((e) => e.response, 'response', isNull),
      ),
    );
    expect(tokens.accessToken, 'at-old');
    expect(await tokens.readRefreshToken(), 'rt-1');
    expect(expiredCalls, 0);
  });

  test('갱신이 503·429 면 토큰을 지우지 않고 그 오류를 넘긴다', () async {
    for (final status in [503, 429]) {
      FlutterSecureStorage.setMockInitialValues({'refresh_token': 'rt-1'});
      tokens.accessToken = 'at-old';
      setUpDio((o) async {
        if (o.path == _refresh) {
          return _json(status, {'code': 'X', 'message': '잠시 후 다시 시도'});
        }
        return _json(401, _unauthorized);
      });
      await expectLater(
        dio.get<dynamic>(_protected),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            status,
          ),
        ),
        reason: '$status',
      );
      expect(tokens.accessToken, 'at-old', reason: '$status');
      expect(await tokens.readRefreshToken(), 'rt-1', reason: '$status');
    }
    expect(expiredCalls, 0);
  });

  test('갱신이 400(형식 오류 토큰)이면 만료로 보고 토큰을 지운다', () async {
    setUpDio((o) async {
      if (o.path == _refresh) {
        return _json(400, {'code': 'INVALID_INPUT', 'message': '입력 오류'});
      }
      return _json(401, _unauthorized);
    });
    await expectLater(dio.get<dynamic>(_protected), throwsA(isA<DioException>()));
    expect(await tokens.readRefreshToken(), isNull);
    expect(expiredCalls, 1);
  });
}
