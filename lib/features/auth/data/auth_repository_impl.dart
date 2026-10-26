import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/session/role.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/models.dart';

/// 실서버 구현. 경로·본문은 docs/api/openapi.yaml(api-v0.3) 그대로.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  @override
  Future<InviteRole> checkInviteCode({
    required String code,
    required String email,
  }) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/invite-codes/verify',
        data: {'inviteCode': code, 'email': email},
      );
      return switch (res.data!['role']) {
        'TEACHER' => InviteRole.teacher,
        'PARENT' => InviteRole.parent,
        _ => throw const AppException(message: AppException.fallbackMessage),
      };
    });
  }

  @override
  Future<PendingSignup> startSignup(SignupForm form) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup',
        data: {
          'inviteCode': form.inviteCode,
          'name': form.name,
          'email': form.email,
          'password': form.password,
          'termsAgreed': form.termsAgreed,
        },
      );
      final data = res.data!;
      return PendingSignup(
        pendingSignupId: data['pendingSignupId'] as String,
        codeExpiresIn: Duration(seconds: data['codeExpiresInSeconds'] as int),
      );
    });
  }

  @override
  Future<AuthResult> verifySignup(String pendingSignupId, String code) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup/verify',
        data: {'pendingSignupId': pendingSignupId, 'code': code},
      );
      return AuthResult(role: await _saveTokens(res.data!));
    });
  }

  @override
  Future<void> resendSignupCode(String pendingSignupId) {
    return mapDioErrors(() async {
      await _dio.post<void>(
        '/api/v1/auth/signup/resend',
        data: {'pendingSignupId': pendingSignupId},
      );
    });
  }

  @override
  Future<AuthResult> login({required String email, required String password}) {
    return mapDioErrors(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResult(role: await _saveTokens(res.data!));
    });
  }

  @override
  Future<Role?> restoreSession() async {
    final rt = await _tokens.readRefreshToken();
    if (rt == null) return null;
    try {
      return await mapDioErrors(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/token/refresh',
          data: {'refreshToken': rt},
        );
        return _saveTokens(res.data!);
      });
    } on AppException catch (e) {
      if (e.isUnauthorized) await _tokens.clear();
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await mapDioErrors(() => _dio.post<void>('/api/v1/auth/logout'));
    } finally {
      await _tokens.clear(); // 서버 결과와 관계없이 기기 세션 삭제(FR-022)
    }
  }

  @override
  Future<void> requestPasswordReset(String email) {
    return mapDioErrors(() async {
      await _dio.post<void>(
        '/api/v1/auth/password-reset',
        data: {'email': email},
      );
    });
  }

  @override
  Future<void> verifyPasswordResetCode(String email, String code) {
    return mapDioErrors(() async {
      await _dio.post<void>(
        '/api/v1/auth/password-reset/verify',
        data: {'email': email, 'code': code},
      );
    });
  }

  @override
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String newPassword,
  ) {
    return mapDioErrors(() async {
      await _dio.post<void>(
        '/api/v1/auth/password-reset/confirm',
        data: {'email': email, 'code': code, 'newPassword': newPassword},
      );
      await _tokens.clear(); // 모든 세션 폐기(FR-025)
    });
  }

  /// TokenResponse 저장 후 역할을 돌려준다. 모르는 역할이면 토큰을 지우고 실패시킨다.
  Future<Role> _saveTokens(Map<String, dynamic> data) async {
    final Role role;
    try {
      role = Role.fromServer(data['role'] as String);
    } on FormatException {
      await _tokens.clear();
      throw const AppException(message: AppException.fallbackMessage);
    }
    _tokens.accessToken = data['accessToken'] as String;
    await _tokens.saveRefreshToken(data['refreshToken'] as String);
    return role;
  }
}
