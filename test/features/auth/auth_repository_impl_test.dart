import 'dart:convert';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/auth/data/auth_repository_impl.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/domain/models.dart';
import 'package:damso_app/features/auth/presentation/login_view_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 요청마다 [body] 를 200 으로 돌려주는 가짜 어댑터.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body);

  Object? body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 보안 저장소 쓰기가 실패하는 기기(Keystore 오류 등).
class _FailingTokenStore extends TokenStore {
  @override
  Future<void> saveRefreshToken(String token) =>
      Future.error(PlatformException(code: 'keystore-broken'));
}

const _tokenResponse = {
  'accessToken': 'at',
  'accessTokenExpiresInSeconds': 900,
  'refreshToken': 'rt',
  'refreshTokenExpiresInSeconds': 1209600,
  'role': 'PARENT',
};

void main() {
  late TokenStore tokens;
  late _FixedAdapter adapter;
  late AuthRepositoryImpl repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tokens = TokenStore();
    adapter = _FixedAdapter(_tokenResponse);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    repo = AuthRepositoryImpl(dio, tokens);
  });

  Matcher fallback() => throwsA(
    isA<AppException>().having(
      (e) => e.message,
      'message',
      AppException.fallbackMessage,
    ),
  );

  test('로그인 응답에 필드가 빠지거나 역할을 모르면 일반 안내, 토큰은 저장하지 않는다', () async {
    for (final broken in [
      {..._tokenResponse}..remove('accessToken'),
      {..._tokenResponse}..remove('refreshToken'),
      {..._tokenResponse, 'role': 'GUEST'},
    ]) {
      adapter.body = broken;
      await expectLater(
        repo.login(email: 'a@damso.test', password: 'damso1234'),
        fallback(),
        reason: '$broken',
      );
      expect(tokens.accessToken, isNull);
      expect(await tokens.readRefreshToken(), isNull);
    }
  });

  test('가입 응답 형식이 다르면 일반 안내', () async {
    adapter.body = {'codeExpiresInSeconds': 600}; // pendingSignupId 없음
    await expectLater(
      repo.startSignup(
        const SignupForm(
          inviteCode: 'PARENTCDE2',
          name: '김학부모',
          email: 'a@damso.test',
          password: 'damso1234',
          termsAgreed: true,
        ),
      ),
      fallback(),
    );
  });

  test('로그인 응답 형식 오류 뒤에도 안내가 보이고 다시 로그인할 수 있다', () async {
    adapter.body = {..._tokenResponse}..remove('accessToken');
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(loginViewModelProvider, (_, _) {});
    final vm = container.read(loginViewModelProvider.notifier);

    await vm.login(email: 'a@damso.test', password: 'damso1234');
    final state = container.read(loginViewModelProvider);
    expect(state.isSubmitting, isFalse);
    expect(state.errorMessage, AppException.fallbackMessage);

    await vm.login(email: 'a@damso.test', password: 'damso1234');
    expect(adapter.calls, 2); // 제출 중 상태에 막히지 않고 다시 요청한다
  });

  test('갱신 토큰 저장이 실패하면 일반 안내로 바꾸고 접근 토큰도 남기지 않는다', () async {
    final failing = _FailingTokenStore();
    final failingRepo = AuthRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
      failing,
    );
    await expectLater(
      failingRepo.login(email: 'a@damso.test', password: 'damso1234'),
      fallback(),
    );
    expect(failing.accessToken, isNull);
  });
}
