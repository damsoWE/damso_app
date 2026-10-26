import 'package:dio/dio.dart';

import '../error/error_codes.dart';
import '../storage/token_store.dart';

/// 토큰 주입·갱신의 단일 지점. 다른 곳에서 Authorization 헤더를 직접 만들지 않는다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._dio,
    this._tokens, {
    required void Function() onSessionExpired,
  }) : _onSessionExpired = onSessionExpired;

  static const refreshPath = '/api/v1/auth/token/refresh';

  /// Authorization 을 붙이지 않고, 401 이어도 갱신하지 않는 경로(contracts/api-usage.md 🔓).
  static const publicPaths = {
    '/api/v1/auth/invite-codes/verify',
    '/api/v1/auth/login',
    '/api/v1/auth/signup',
    '/api/v1/auth/signup/verify',
    '/api/v1/auth/signup/resend',
    '/api/v1/auth/password-reset',
    '/api/v1/auth/password-reset/verify',
    '/api/v1/auth/password-reset/confirm',
    refreshPath,
  };

  static const _retriedKey = 'auth_retried';

  final Dio _dio;
  final TokenStore _tokens;
  final void Function() _onSessionExpired;

  /// 진행 중인 갱신. 동시에 401 을 받은 요청은 이 결과를 함께 기다린다(RT 는 1회용).
  Future<_RefreshResult>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final at = _tokens.accessToken;
    if (at != null && !publicPaths.contains(options.path)) {
      options.headers['Authorization'] = 'Bearer $at';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final res = err.response;
    if (res?.statusCode != 401 ||
        publicPaths.contains(req.path) ||
        req.extra[_retriedKey] == true ||
        _codeOf(res) == ErrorCodes.invalidCredentials) {
      return handler.next(err);
    }

    // 실패한 요청을 보낸 뒤 이미 다른 요청이 갱신을 마쳤다면 갱신 없이 재시도만 한다.
    final sentToken = req.headers['Authorization'];
    final current = _tokens.accessToken;
    final alreadyRefreshed = current != null && sentToken != 'Bearer $current';

    if (!alreadyRefreshed) {
      final result = await (_refreshing ??= _refresh().whenComplete(
        () => _refreshing = null,
      ));
      if (result.networkError != null) return handler.next(result.networkError!);
      if (!result.ok) return handler.next(err);
    }

    req.extra[_retriedKey] = true; // 재시도는 한 번만.
    try {
      handler.resolve(await _dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<_RefreshResult> _refresh() async {
    final rt = await _tokens.readRefreshToken();
    if (rt == null) {
      await _expire();
      return const _RefreshResult(ok: false);
    }
    // 인터셉터가 없는 별도 Dio 로 호출해 무한 재귀를 막는다.
    final plain = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
      ),
    )..httpClientAdapter = _dio.httpClientAdapter;
    try {
      final res = await plain.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': rt},
      );
      final data = res.data;
      final at = data?['accessToken'];
      final newRt = data?['refreshToken'];
      if (at is! String || newRt is! String) {
        await _expire();
        return const _RefreshResult(ok: false);
      }
      _tokens.accessToken = at;
      await _tokens.saveRefreshToken(newRt);
      return const _RefreshResult(ok: true);
    } on DioException catch (e) {
      if (e.response == null) {
        // 네트워크 오류: 세션은 살아 있을 수 있으므로 토큰을 지우지 않는다.
        return _RefreshResult(ok: false, networkError: e);
      }
      await _expire(); // 만료·폐기·재사용 탐지 → 로그인 화면
      return const _RefreshResult(ok: false);
    }
  }

  Future<void> _expire() async {
    await _tokens.clear();
    _onSessionExpired();
  }

  static String? _codeOf(Response<dynamic>? res) {
    final data = res?.data;
    final code = data is Map ? data['code'] : null;
    return code is String ? code : null;
  }
}

class _RefreshResult {
  const _RefreshResult({required this.ok, this.networkError});

  final bool ok;
  final DioException? networkError;
}
