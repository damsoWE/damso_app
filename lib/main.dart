import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/push/push_messaging_provider.dart';

/// 진입점. 실행: flutter run --dart-define-from-file=env/prod.json(배포 서버) 또는 env/dev.json(로컬 서버)
/// 서버 없이 실행하려면 USE_MOCK=true (예: --dart-define=USE_MOCK=true).
/// 기기 알림은 --dart-define-from-file=secrets/firebase.json 이 있을 때만 켠다.
Future<void> main() async {
  Env.ensureConfigured();
  WidgetsFlutterBinding.ensureInitialized();
  await initPushMessaging();
  runApp(
    // 실패한 조회를 자동 재시도하지 않는다. 다시 시도는 화면의 버튼으로만 한다(FR-041).
    ProviderScope(retry: (_, _) => null, child: const DamsoApp()),
  );
}
