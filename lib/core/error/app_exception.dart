import 'package:dio/dio.dart';

/// 앱 안에서 쓰는 오류 타입. data 계층이 DioException 을 이 타입으로 바꿔 던지고,
/// ViewModel·화면은 dio 타입을 다루지 않는다.
/// 화면에는 [message] 만 보여 준다(예외 객체·스택트레이스 노출 금지, 원칙 6).
/// 서버 ErrorResponse 의 fieldErrors 는 openapi.yaml 확정 후 추가한다.
class AppException implements Exception {
  const AppException({required this.message, this.code, this.statusCode});

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  final String message;
  final String? code;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  factory AppException.fromDio(DioException e) {
    final data = e.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;
    final code = data is Map<String, dynamic> ? data['code'] : null;
    return AppException(
      message: message is String && message.isNotEmpty
          ? message
          : _fallbackMessage,
      code: code is String ? code : null,
      statusCode: e.response?.statusCode,
    );
  }
}

/// data 계층에서 dio 호출을 감싸 DioException 을 [AppException] 으로 변환한다.
Future<T> mapDioErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw AppException.fromDio(e);
  }
}
