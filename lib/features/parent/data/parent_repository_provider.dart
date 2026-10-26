import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/storage/token_store.dart';
import '../domain/parent_repository.dart';
import 'mock_parent_repository.dart';
import 'parent_repository_impl.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  if (Env.useMock) {
    return MockParentRepository(
      ref.watch(tokenStoreProvider),
      () => ref.read(sessionControllerProvider.notifier).expire(),
    );
  }
  return ParentRepositoryImpl(ref.watch(dioProvider));
});
