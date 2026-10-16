import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/inquiry_repository.dart';
import 'inquiry_repository_impl.dart';
import 'mock_inquiry_repository.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final inquiryRepositoryProvider = Provider<InquiryRepository>((ref) {
  if (Env.useMock) return MockInquiryRepository();
  return InquiryRepositoryImpl(ref.watch(dioProvider));
});
