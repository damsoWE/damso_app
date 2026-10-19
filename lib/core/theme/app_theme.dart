import 'package:flutter/material.dart';

// 값의 출처: Figma `디자인_semi_final` 페이지 — 변수 컬렉션 `담소 v2`의 `컬러` 모드,
// 텍스트 스타일 `담소/…`. Figma 값이 바뀌면 이 파일만 고친다.

/// 간격 상수. 화면마다 숫자를 직접 쓰지 않고 여기서 가져온다. (Figma `space/*`)
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const ms = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

/// 모서리 둥글기. (Figma `radius/*`)
class AppRadius {
  const AppRadius._();

  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

/// 색 토큰. (Figma `color/*`, `컬러` 모드)
class AppColors {
  const AppColors._();

  // 배경
  static const bgCanvas = Color(0xFFFAF7F2);
  static const bgSurface = Color(0xFFF9FFFD);
  static const bgSubtle = Color(0xFFE9F0F7);

  // 글자
  static const textPrimary = Color(0xFF24313A);
  static const textSecondary = Color(0xFF6A6C66);
  static const textTertiary = Color(0xFF6A6C66);
  static const textInverse = Color(0xFFFFFFFF);

  // 브랜드
  static const brandPrimary = Color(0xFF3F7665);
  static const brandAccent = Color(0xFFF3A76F);
  static const brandAccentSoft = Color(0xFFDCEFE8);

  // 테두리 — 입력칸은 대비 3:1을 위해 borderInput을 쓴다
  static const borderDefault = Color(0xFFD4D9DD);
  static const borderStrong = Color(0xFFCBC2B4);
  static const borderInput = Color(0xFF958F83);

  // 상태 — 연한 배경 위 글자는 *Text 또는 textPrimary를 쓴다
  static const statusUrgent = Color(0xFFBD5047);
  static const statusUrgentSoft = Color(0xFFFBE4E1);
  static const statusUrgentText = Color(0xFFA8433A);
  static const statusWarning = Color(0xFF7E5A0A);
  static const statusWarningSoft = Color(0xFFFBF1DC);
  static const statusSuccess = Color(0xFF2E5E4F);
  static const statusSuccessSoft = Color(0xFFDCEFE8);
  static const statusInfo = Color(0xFF8A4A1C);
  static const statusInfoSoft = Color(0xFFFCE8D7);
  static const statusSystem = Color(0xFF5C5E58);
  static const statusSystemSoft = Color(0x80D4D9DD);

  // 정서 강도
  static const emotionLow = Color(0xFF3F7665);
  static const emotionMid = Color(0xFFF3A76F);
  static const emotionHigh = Color(0xFFD7655B);
  static const emotionLowText = Color(0xFF2E5E4F);
  static const emotionMidText = Color(0xFF85600A);
  static const emotionHighText = Color(0xFFA8433A);
}

/// 글자 스타일. (Figma 텍스트 스타일 `담소/…`)
/// Figma 글꼴은 Noto Sans KR이다. 앱에 글꼴을 넣는 방식이 정해지기 전까지는 기본 글꼴을 쓴다.
class AppTextStyles {
  const AppTextStyles._();

  static const display = TextStyle(fontSize: 26, height: 36 / 26, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  static const title = TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static const subtitle = TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w700, letterSpacing: -0.2);
  static const body = TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w700);
  static const small = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const smallStrong = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static const micro = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500);
  static const label = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w700);
}

/// 앱 테마 한 곳.
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.textInverse,
    secondary: AppColors.brandAccent,
    onSecondary: AppColors.textPrimary,
    error: AppColors.statusUrgent,
    onError: AppColors.textInverse,
    surface: AppColors.bgSurface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.borderInput,
    outlineVariant: AppColors.borderDefault,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.bgCanvas,
    dividerColor: AppColors.borderDefault,
    textTheme: const TextTheme(
      headlineSmall: AppTextStyles.display,
      titleLarge: AppTextStyles.title,
      titleMedium: AppTextStyles.subtitle,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.small,
      bodySmall: AppTextStyles.micro,
      labelLarge: AppTextStyles.bodyStrong,
      labelMedium: AppTextStyles.smallStrong,
      labelSmall: AppTextStyles.label,
    ).apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary),
  );
}
