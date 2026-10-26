import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_store.dart';
import '../domain/teacher_repository.dart';
import 'mock_teacher_repository.dart';
import 'teacher_repository_impl.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  if (Env.useMock) return MockTeacherRepository(ref.watch(tokenStoreProvider));
  return TeacherRepositoryImpl(ref.watch(dioProvider));
});
