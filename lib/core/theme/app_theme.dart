import 'package:flutter/material.dart';

// 값의 출처: Figma `디자인_semi_final` 페이지 — 변수 컬렉션 `담소 v3`의 `컬러` 모드,
// 텍스트 스타일 `담소/…`. 단 메인·배경·글자·경계선·오류 색은 Figma `프로젝트 핵심 칼라 표`(216:7012)를
// 따른다(사용자 지정, 2026-10-29 — 변수 값과 다른 곳은 표가 우선). 값이 바뀌면 이 파일만 고친다.

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
  static const bgCanvas = Color(0xFFFAF7F2); // 전체 배경 · 종이 크림
  static const bgSurface = Color(0xFFFFFFFF); // 카드 배경 · 화이트
  static const bgSubtle = Color(0xFFE9F0F7);

  // 글자
  static const textPrimary = Color(0xFF24313A);
  static const textSecondary = Color(0xFF73756F); // 보조 글자 · 웜 그레이
  static const textTertiary = Color(0xFF73756F);
  static const textInverse = Color(0xFFFFFFFF);

  // 브랜드
  static const brandPrimary = Color(0xFF3F7665); // 메인 컬러 · 칠판 그린
  static const brandAccent = Color(0xFFF3A76F); // 강조 컬러 · 살구 오렌지
  static const brandAccentSoft = Color(0xFFDCEFE8); // 메인 연한 배경 · 민트 크림

  // 테두리 — 입력칸은 대비 3:1을 위해 borderInput을 쓴다
  static const borderDefault = Color(0xFFE7E1D8); // 경계선 · 라이트 베이지
  static const borderStrong = Color(0xFFCBC2B4);
  static const borderInput = Color(0xFF958F83);

  /// 오류 · 코랄 레드(입력 오류 테두리·오류 글자, 테마 error).
  static const error = Color(0xFFD7655B);

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
    error: AppColors.error,
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
    // 화면 바탕은 "메인 연한 배경 · 민트 크림"을 쓴다(사용자 지정, 2026-10-29).
    scaffoldBackgroundColor: AppColors.brandAccentSoft,
    dividerColor: AppColors.borderDefault,
    // 헤더(앱 바)도 화면 바탕과 같은 민트 크림. 스크롤해도 색이 바뀌지 않게 한다(사용자 지정, 2026-10-29).
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandAccentSoft,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.textPrimary,
    ),
    // Figma Button: 높이 52, 가로 여백 20, 모서리 radius/md, 글자 `담소/Body Strong`.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: AppTextStyles.bodyStrong,
      ),
    ),
    // Figma Button `Secondary`: 흰 바탕 + border/strong 테두리 + 진한 글자.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: AppTextStyles.bodyStrong,
        backgroundColor: AppColors.bgSurface,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderStrong),
      ),
    ),
    // Figma Input: 흰 바탕, 모서리 radius/md, 기본 1px·입력 중 1.5px border/input, 오류 1.5px(오류 색).
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
      helperStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
      border: _inputBorder(AppColors.borderInput, 1),
      enabledBorder: _inputBorder(AppColors.borderInput, 1),
      focusedBorder: _inputBorder(AppColors.borderInput, 1.5),
      errorBorder: _inputBorder(AppColors.error, 1.5),
      focusedErrorBorder: _inputBorder(AppColors.error, 1.5),
      disabledBorder: _inputBorder(AppColors.borderDefault, 1),
    ),
    // Figma 하단 탭: 활성은 브랜드 색 아이콘 + 진한 굵은 글자, 비활성은 회색. 주황 표시기는 없다.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bgSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.brandPrimary
              : AppColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppTextStyles.micro.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              )
            : AppTextStyles.micro.copyWith(color: AppColors.textSecondary),
      ),
    ),
    // Figma 스위치: 켜짐은 주황(brand/accent), 흰 손잡이.
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.textInverse),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.brandAccent
            : AppColors.borderStrong,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    // Figma 요일 칩: 선택은 브랜드 색 + 흰 글자, 비선택은 bg/subtle + 진한 글자.
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgSubtle,
      selectedColor: AppColors.brandPrimary,
      showCheckmark: false,
      side: BorderSide.none,
      // Chip 은 글자 스타일이 아니라 글자 색만 상태별로 고르므로 색을 WidgetStateColor 로 준다.
      labelStyle: AppTextStyles.smallStrong.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.textInverse
              : AppColors.textPrimary,
        ),
      ),
    ),
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

OutlineInputBorder _inputBorder(Color color, double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.md),
  borderSide: BorderSide(color: color, width: width),
);
