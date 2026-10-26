import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_repository_provider.dart';

/// 앱 시작 시 세션 복구(research R2). core 가 auth 기능을 참조하지 않도록 여기서 호출한다.
class SplashViewModel extends Notifier<void> {
  bool _running = false;

  @override
  void build() {}

  Future<void> restore() async {
    if (_running) return;
    _running = true;
    final session = ref.read(sessionControllerProvider.notifier);
    try {
      final role = await ref.read(authRepositoryProvider).restoreSession();
      if (role == null) {
        await session.signOut(); // 저장된 토큰 없음 → 시작 화면
      } else {
        session.signIn(role);
      }
    } on AppException catch (e) {
      if (e.isUnauthorized) {
        await session.expire(); // 서버가 거부 → 로그인 화면
      } else {
        session.markUnreachable(); // 토큰은 유지하고 다시 시도
      }
    } finally {
      _running = false;
    }
  }

  Future<void> retry() async {
    ref.read(sessionControllerProvider.notifier).retryRestore();
    await restore();
  }
}

final splashViewModelProvider = NotifierProvider<SplashViewModel, void>(
  SplashViewModel.new,
);
