import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/session/role.dart';
import '../../../core/storage/token_store.dart';
import '../domain/me.dart';
import '../domain/me_repository.dart';

/// 실서버 구현. 경로는 docs/api/openapi.yaml(api-v0.3) 그대로.
class MeRepositoryImpl implements MeRepository {
  MeRepositoryImpl(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  @override
  Future<Me> getMe() {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/me');
      return _me(res.data!);
    });
  }

  @override
  Future<Me> updateName(String name) {
    return mapDioErrors(() async {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/me',
        data: {'name': name},
      );
      return _me(res.data!);
    });
  }

  @override
  Future<void> withdraw(String password) {
    return mapDioErrors(() async {
      await _dio.post<void>(
        '/api/v1/me/withdrawal',
        data: {'password': password},
      );
      await _tokens.clear();
    });
  }

  static Me _me(Map<String, dynamic> j) => Me(
    userId: j['userId'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    role: Role.fromServer(j['role'] as String),
  );
}
