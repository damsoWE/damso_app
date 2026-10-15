import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'mock/mock_overrides.dart';

/// Mock 진입점(서버 불필요). 실행: flutter run -t lib/main_mock.dart
void main() {
  runApp(ProviderScope(overrides: mockOverrides, child: const DamsoApp()));
}
