import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 알림을 눌러 열었는데 아직 로그인 전일 때 이동할 경로 하나(메모리, data-model §5).
/// 교사로 로그인하면 라우터가 역할 홈 대신 이 경로로 보내고 비운다.
class PendingNavigation extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String path) => state = path;

  void clear() => state = null;
}

final pendingNavigationProvider = NotifierProvider<PendingNavigation, String?>(
  PendingNavigation.new,
);
