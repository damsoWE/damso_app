import 'package:damso_app/core/error/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _withResponse(
  int status, {
  Object? data,
  Map<String, List<String>> headers = const {},
}) {
  final req = RequestOptions(path: '/api/v1/test');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: req,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );
}

DioException _noResponse(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/x'), type: type);

void main() {
  group('AppException.fromDio', () {
    test('서버 message 와 code, statusCode 를 그대로 쓴다', () {
      final e = AppException.fromDio(
        _withResponse(
          403,
          data: {'code': 'FORBIDDEN', 'message': '권한이 없습니다.'},
        ),
      );
      expect(e.message, '권한이 없습니다.');
      expect(e.code, 'FORBIDDEN');
      expect(e.statusCode, 403);
      expect(e.isNetworkError, isFalse);
    });

    test('message 가 없거나 비어 있으면 고정 일반 안내', () {
      expect(
        AppException.fromDio(_withResponse(500, data: null)).message,
        AppException.fallbackMessage,
      );
      expect(
        AppException.fromDio(
          _withResponse(500, data: {'code': 'INTERNAL_ERROR', 'message': ''}),
        ).message,
        AppException.fallbackMessage,
      );
    });

    test('fieldErrors 를 field → reason 으로, 같은 field 는 첫 번째만', () {
      final e = AppException.fromDio(
        _withResponse(
          400,
          data: {
            'code': 'INVALID_INPUT',
            'message': '입력값이 올바르지 않습니다.',
            'fieldErrors': [
              {'field': 'email', 'reason': '형식이 올바르지 않습니다'},
              {'field': 'email', 'reason': '두 번째'},
              {'field': 'name', 'reason': '최대 20자입니다'},
            ],
          },
        ),
      );
      expect(e.fieldErrors, {
        'email': '형식이 올바르지 않습니다',
        'name': '최대 20자입니다',
      });
    });

    test('429 Retry-After 를 초 단위 Duration 으로 읽는다', () {
      final e = AppException.fromDio(
        _withResponse(
          429,
          data: {'code': 'TOO_MANY_ATTEMPTS', 'message': '잠시 후 다시 시도해 주세요.'},
          headers: {
            'retry-after': ['30'],
          },
        ),
      );
      expect(e.retryAfter, const Duration(seconds: 30));
    });

    test('Retry-After 가 없거나 숫자가 아니면 null', () {
      expect(AppException.fromDio(_withResponse(429)).retryAfter, isNull);
      expect(
        AppException.fromDio(
          _withResponse(
            429,
            headers: {
              'retry-after': ['soon'],
            },
          ),
        ).retryAfter,
        isNull,
      );
    });

    test('응답이 없으면 네트워크 오류 + 네트워크 고정 안내', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final e = AppException.fromDio(_noResponse(type));
        expect(e.isNetworkError, isTrue, reason: '$type');
        expect(e.message, AppException.networkMessage);
        expect(e.statusCode, isNull);
      }
    });
  });

  test('userMessageOf 는 AppException 이 아니면 일반 안내만 준다', () {
    expect(userMessageOf(const AppException(message: '서버 안내')), '서버 안내');
    expect(userMessageOf(StateError('내부 오류')), AppException.fallbackMessage);
  });

  group('mapDioErrors', () {
    test('응답 형식 오류(TypeError·FormatException)는 일반 안내로 바꾼다', () async {
      final Map<String, dynamic> body = {'accessToken': null};
      await expectLater(
        mapDioErrors(() async => body['accessToken'] as String),
        throwsA(
          isA<AppException>()
              .having((e) => e.message, 'message', AppException.fallbackMessage)
              .having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
      await expectLater(
        mapDioErrors(() async => DateTime.parse('어제')),
        throwsA(isA<AppException>()),
      );
    });

    test('직접 던진 AppException 은 그대로 둔다', () async {
      await expectLater(
        mapDioErrors<void>(
          () async => throw const AppException(message: '서버 안내', code: 'X'),
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'X')),
      );
    });
  });
}
