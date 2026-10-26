import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_store.dart';
import '../domain/me_repository.dart';
import 'me_repository_impl.dart';
import 'mock_me_repository.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final meRepositoryProvider = Provider<MeRepository>((ref) {
  if (Env.useMock) return MockMeRepository(ref.watch(tokenStoreProvider));
  return MeRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(tokenStoreProvider),
  );
});
