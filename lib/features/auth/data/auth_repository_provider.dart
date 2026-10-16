import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/auth_repository.dart';
import 'auth_repository_impl.dart';
import 'mock_auth_repository.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useMock) return MockAuthRepository();
  return AuthRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(tokenStoreProvider),
  );
});
