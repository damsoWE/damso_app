import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_store.dart';
import '../../inquiry/data/inquiry_repository_providers.dart';
import '../domain/answer_repository.dart';
import 'answer_repository_impl.dart';
import 'mock_answer_repository.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final answerRepositoryProvider = Provider<AnswerRepository>((ref) {
  if (Env.useMock) {
    return MockAnswerRepository(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    );
  }
  return AnswerRepositoryImpl(ref.watch(dioProvider));
});
