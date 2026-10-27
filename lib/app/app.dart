import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'push_listener.dart';
import 'router.dart';

/// 앱 루트 위젯: 테마와 라우터를 연결하고 기기 알림을 듣는다.
class DamsoApp extends ConsumerWidget {
  const DamsoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PushListener(
      child: MaterialApp.router(
        title: '담소',
        theme: buildAppTheme(),
        scaffoldMessengerKey: scaffoldMessengerKey,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
