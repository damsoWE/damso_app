import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_store.dart';
import '../domain/admin_repository.dart';
import 'admin_repository_impl.dart';
import 'mock_admin_repository.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (Env.useMock) return MockAdminRepository(ref.watch(tokenStoreProvider));
  return AdminRepositoryImpl(ref.watch(dioProvider));
});
