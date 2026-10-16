import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';

/// 진입점. 실행: flutter run --dart-define-from-file=env/dev.json
/// 서버 없이 실행하려면 USE_MOCK=true (예: --dart-define=USE_MOCK=true).
void main() {
  Env.ensureConfigured();
  runApp(const ProviderScope(child: DamsoApp()));
}
