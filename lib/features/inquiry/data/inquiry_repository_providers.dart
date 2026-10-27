import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_store.dart';
import '../domain/parent_inquiry_repository.dart';
import '../domain/teacher_inquiry_repository.dart';
import 'mock_inquiry_store.dart';
import 'mock_parent_inquiry_repository.dart';
import 'mock_teacher_inquiry_repository.dart';
import 'parent_inquiry_repository_impl.dart';
import 'teacher_inquiry_repository_impl.dart';

/// 학부모·교사 mock 이 공유하는 저장소. 앱 실행 동안 하나다.
final mockInquiryStoreProvider = Provider<MockInquiryStore>(
  (_) => MockInquiryStore(),
);

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final parentInquiryRepositoryProvider = Provider<ParentInquiryRepository>((ref) {
  if (Env.useMock) {
    return MockParentInquiryRepository(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    );
  }
  return ParentInquiryRepositoryImpl(ref.watch(dioProvider));
});

final teacherInquiryRepositoryProvider = Provider<TeacherInquiryRepository>((ref) {
  if (Env.useMock) {
    return MockTeacherInquiryRepository(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    );
  }
  return TeacherInquiryRepositoryImpl(ref.watch(dioProvider));
});
