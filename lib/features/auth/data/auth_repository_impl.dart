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
      // 거절 판단은 AuthInterceptor 와 같은 규칙을 쓴다(5xx·429 는 토큰 유지).
      if (e.isRefreshRejected) await _tokens.clear();
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
    });
  }

  /// TokenResponse 를 모두 확인한 뒤에 저장하고 역할을 돌려준다.
  /// 하나라도 형식이 다르면(모르는 역할 포함) 토큰을 지우고 실패시킨다 — 반쪽만 저장하지 않는다.
  /// 오류는 [mapDioErrors] 가 일반 안내로 바꾼다.
  Future<Role> _saveTokens(Map<String, dynamic> data) async {
    final String accessToken;
    final String refreshToken;
    final Role role;
    try {
      accessToken = data['accessToken'] as String;
      refreshToken = data['refreshToken'] as String;
      role = Role.fromServer(data['role'] as String);
    } catch (_) {
      await _tokens.clear();
      rethrow;
    }
    _tokens.accessToken = accessToken;
    await _tokens.saveRefreshToken(refreshToken);
    return role;
  }
}
