import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/notification_repository.dart';
import 'mock_notification_repository.dart';
import 'notification_repository_impl.dart';

/// 구현체를 고르는 유일한 지점. USE_MOCK 값으로 실서버/mock 을 전환한다.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (Env.useMock) return MockNotificationRepository();
  return NotificationRepositoryImpl(ref.watch(dioProvider));
});
