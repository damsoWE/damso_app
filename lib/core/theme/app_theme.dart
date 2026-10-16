import 'package:flutter/material.dart';

/// 간격 상수. 화면마다 숫자를 직접 쓰지 않고 여기서 가져온다.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
}

/// 앱 테마 한 곳. 색·글꼴 값은 Figma 확정 후 이곳만 바꾼다(현재 임시 값).
ThemeData buildAppTheme() =>
    ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true);
