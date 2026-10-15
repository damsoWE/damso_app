import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// 토큰 주입·갱신의 단일 지점. 다른 곳에서 Authorization 헤더를 직접 만들지 않는다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokens);

  // 갱신 경로 — docs/api/openapi.yaml 확정 후 맞춘다(현재 임시 값).
  static const _refreshPath = '/auth/refresh';
  static const _retriedKey = 'auth_retried';

  final Dio _dio;
  final TokenStore _tokens;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final at = _tokens.accessToken;
    if (at != null) options.headers['Authorization'] = 'Bearer $at';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 || req.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    try {
      if (!await _refresh()) return handler.next(err);
      req.extra[_retriedKey] = true; // RT 는 1회용 — 재시도는 한 번만.
      handler.resolve(await _dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final rt = await _tokens.readRefreshToken();
    if (rt == null) return false;
    try {
      // 인터셉터가 없는 별도 Dio 로 호출해 무한 재귀를 막는다.
      final res = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
          .post<Map<String, dynamic>>(_refreshPath, data: {'refreshToken': rt});
      final data = res.data;
      if (data == null) return false;
      _tokens.accessToken = data['accessToken'] as String?;
      await _tokens.saveRefreshToken(data['refreshToken'] as String);
      return true;
    } on DioException {
      await _tokens.clear(); // 갱신 실패 → 로그아웃 상태로 전환
      return false;
    }
  }
}
