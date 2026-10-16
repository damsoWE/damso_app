import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

/// 앱 전체가 공유하는 HTTP 클라이언트. 로그에 요청/응답 본문을 남기지 않는다(원칙 6).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  dio.interceptors.add(AuthInterceptor(dio, ref.watch(tokenStoreProvider)));
  return dio;
});
