import 'package:dio/dio.dart';

/// 앱 안에서 쓰는 오류 타입. data 계층이 DioException 을 이 타입으로 바꿔 던지고,
/// ViewModel·화면은 dio 타입을 다루지 않는다.
/// 화면에는 [message] 만 보여 준다(예외 객체·스택트레이스 노출 금지, 원칙 6).
/// 분기는 [code] 를 `error_codes.dart` 상수와 비교해서 한다.
class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfter,
    this.isNetworkError = false,
  });

  /// 서버 안내 문구를 받지 못했을 때의 고정 안내.
  static const fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  /// 응답이 없을 때(연결 실패·시간 초과)의 고정 안내.
  static const networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';

  final String message;
  final String? code;
  final int? statusCode;

  /// 입력 오류의 필드별 안내(field → reason). INVALID_INPUT 일 때만 채워진다.
  final Map<String, String> fieldErrors;

  /// 429 의 `Retry-After`(초). 없으면 null.
  final Duration? retryAfter;

  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  /// 토큰 갱신이 이 상태 코드로 거절되면 저장된 갱신 토큰은 다시 써도 소용없다(만료·폐기·형식 오류).
  /// 5xx·429·네트워크 오류는 일시적일 수 있으므로 세션 만료로 보지 않는다.
  static bool isRefreshRejectedStatus(int? statusCode) =>
      statusCode == 400 || statusCode == 401 || statusCode == 403;

  bool get isRefreshRejected => isRefreshRejectedStatus(statusCode);

  factory AppException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      final network = e.type != DioExceptionType.cancel;
      return AppException(
        message: network ? networkMessage : fallbackMessage,
        isNetworkError: network,
      );
    }
    final data = res.data;
    final body = data is Map ? data : const {};
    final message = body['message'];
    final code = body['code'];
    return AppException(
      message: message is String && message.isNotEmpty
          ? message
          : fallbackMessage,
      code: code is String ? code : null,
      statusCode: res.statusCode,
      fieldErrors: _parseFieldErrors(body['fieldErrors']),
      retryAfter: _parseRetryAfter(res.headers.value('retry-after')),
    );
  }

  static Map<String, String> _parseFieldErrors(Object? raw) {
    if (raw is! List) return const {};
    final result = <String, String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final field = item['field'];
      final reason = item['reason'];
      if (field is String && reason is String) {
        result.putIfAbsent(field, () => reason); // 같은 필드는 첫 번째만
      }
    }
    return result;
  }

  static Duration? _parseRetryAfter(String? raw) {
    final seconds = raw == null ? null : int.tryParse(raw.trim());
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}

/// 화면에 보여 줄 문구. [AppException] 이 아니면 내용을 노출하지 않고 일반 안내만 준다.
String userMessageOf(Object error) =>
    error is AppException ? error.message : AppException.fallbackMessage;

/// data 계층에서 dio 호출을 감싸 DioException 을 [AppException] 으로 변환한다.
Future<T> mapDioErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw AppException.fromDio(e);
  }
}
