import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';

/// 실서버 진입점. 실행: flutter run --dart-define-from-file=env/dev.json
void main() {
  Env.ensureConfigured();
  runApp(const ProviderScope(child: DamsoApp()));
}
