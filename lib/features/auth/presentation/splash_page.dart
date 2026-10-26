import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/async_view.dart';
import 'splash_view_model.dart';

/// 세션 확인 중·연결 불가 전용 화면. 이동은 라우터 redirect 가 맡는다.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(sessionControllerProvider) is SessionChecking) {
        ref.read(splashViewModelProvider.notifier).restore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: session is SessionUnreachable
          ? ErrorRetry(
              message: '서버에 연결할 수 없습니다.',
              onRetry: ref.read(splashViewModelProvider.notifier).retry,
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
