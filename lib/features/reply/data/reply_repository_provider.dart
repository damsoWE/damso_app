import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/reply_repository.dart';
import 'mock_reply_repository.dart';
import 'reply_repository_impl.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final replyRepositoryProvider = Provider<ReplyRepository>((ref) {
  if (Env.useMock) return MockReplyRepository();
  return ReplyRepositoryImpl(ref.watch(dioProvider));
});
