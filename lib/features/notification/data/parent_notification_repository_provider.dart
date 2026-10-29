import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/parent_notification_repository.dart';
import 'parent_notification_repository_impl.dart';

/// 구현체를 고르는 유일한 지점. mock 분기는 없다 — 실서버로만 확인한다(specs/007 research R9).
final parentNotificationRepositoryProvider = Provider<ParentNotificationRepository>(
  (ref) => ParentNotificationRepositoryImpl(ref.watch(dioProvider)),
);
