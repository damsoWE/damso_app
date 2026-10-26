import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';

/// 진입점. 실행: flutter run --dart-define-from-file=env/dev.json
/// 서버 없이 실행하려면 USE_MOCK=true (예: --dart-define=USE_MOCK=true).
void main() {
  Env.ensureConfigured();
  runApp(
    // 실패한 조회를 자동 재시도하지 않는다. 다시 시도는 화면의 버튼으로만 한다(FR-041).
    ProviderScope(retry: (_, _) => null, child: const DamsoApp()),
  );
}
