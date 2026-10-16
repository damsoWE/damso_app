import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';

/// 실서버 구현. 엔드포인트는 docs/api/openapi.yaml 확정 후 맞춘다(현재 임시 값).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  @override
  Future<void> login({required String email, required String password}) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = res.data!;
      _tokens.accessToken = data['accessToken'] as String;
      await _tokens.saveRefreshToken(data['refreshToken'] as String);
    });
  }

  @override
  Future<void> logout() => _tokens.clear();
}
