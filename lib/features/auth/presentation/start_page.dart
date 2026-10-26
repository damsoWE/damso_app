import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// C-0 시작 (Figma 285-6781).
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const Expanded(child: Center(child: _Hero())),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.ms,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: _buttonShape,
                      textStyle: AppTextStyles.bodyStrong,
                    ),
                    child: const Text('로그인'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => context.push('/signup'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: _buttonShape,
                      side: const BorderSide(color: AppColors.borderStrong),
                      foregroundColor: AppColors.textPrimary,
                      textStyle: AppTextStyles.bodyStrong,
                    ),
                    child: const Text('초대코드로 가입하기'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '학교에서 받은 초대코드가 있어야 가입할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로고 + 서비스 이름.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 11, AppSpacing.lg, 0),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Image.asset(_asset('logo_icon'), width: 25, height: 25),
          ),
          const SizedBox(width: 14),
          Text(
            '담소',
            style: AppTextStyles.display.copyWith(
              fontSize: 28,
              height: 36 / 28,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 가운데 일러스트와 소개 문구. Figma 좌표(390 폭 기준)를 그대로 두고 화면 폭에 맞춰 늘이고 줄인다.
class _Hero extends StatelessWidget {
  const _Hero();

  static const _width = 390.0;
  static const _height = 375.0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: _width,
        height: _height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ExcludeSemantics(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _image('glow_outer', 25, 2, 339, 254),
                  _image('glow_inner', 82, 47, 226, 162),
                  _image('house_home', -2, 39, 191, 159),
                  _image('house_school', 199, 45, 191, 148),
                  _image('bridge', 120, 103, 144, 72),
                  _image('parent', 107, 129, 65, 97),
                  _image('shield', 140, 41, 110, 92),
                  _image('teacher', 215, 133, 60, 90),
                  // 상담요청 말풍선
                  _rotated(83.21, 44.76, 81.33, 32.91, -5.46, _bubble(79.26, 25.48)),
                  _rotated(88.81, 55.62, 17.23, 17.23, -5.46, _img('check', 15.8, 15.8)),
                  _rotated(95, 39, 70.84, 41.57, -5.46, _bubbleText('상담요청', 12)),
                  // 답변 도착 말풍선
                  _rotated(260.44, 178.97, 113.2, 38.14, 6.36, _bubble(111, 26)),
                  _rotated(273.91, 175.55, 104.26, 45.98, 6.36, _bubbleText('답변이 도착했어요', 10)),
                  _rotated(262.43, 179.19, 28.72, 28.72, 6.36, _img('bell', 26, 26)),
                  _rotated(50, 47, 27.24, 23.82, -9.17, _img('star', 24.33, 20.21)),
                  _rotated(312, 71, 27.24, 23.82, -9.17, _img('star', 24.33, 20.21)),
                  // 구름
                  Positioned(
                    left: 94,
                    top: 231,
                    child: Opacity(opacity: 0.7, child: _img('cloud', 360, 144)),
                  ),
                  Positioned(
                    left: -83,
                    top: 173,
                    child: Transform.flip(
                      flipX: true,
                      child: Opacity(opacity: 0.68, child: _img('cloud', 360, 144)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 21,
              top: 209,
              width: 342,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '학교와 가정의 이야기,\n'),
                    TextSpan(
                      text: '담소',
                      style: TextStyle(color: AppColors.brandPrimary),
                    ),
                    const TextSpan(text: '에서 편안하게 나눠요'),
                  ],
                ),
                style: AppTextStyles.display.copyWith(
                  fontSize: 25,
                  height: 36 / 25,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _img(String name, double width, double height) =>
      Image.asset(_asset(name), width: width, height: height, fit: BoxFit.cover);

  static Widget _image(
    String name,
    double left,
    double top,
    double width,
    double height,
  ) => Positioned(left: left, top: top, child: _img(name, width, height));

  /// Figma 에서 회전한 레이어. [left]·[top]·[width]·[height] 는 회전 후 차지하는 영역이다.
  static Widget _rotated(
    double left,
    double top,
    double width,
    double height,
    double degrees,
    Widget child,
  ) => Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: Center(
      child: Transform.rotate(angle: degrees * math.pi / 180, child: child),
    ),
  );

  static Widget _bubble(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDFC),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      boxShadow: const [
        BoxShadow(color: Color(0x40000000), offset: Offset(1, 3), blurRadius: 4),
      ],
    ),
  );

  static Widget _bubbleText(String text, double size) => Text(
    text,
    maxLines: 1,
    textScaler: TextScaler.noScaling, // 그림의 일부라 글자 크기 설정을 따르지 않는다
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: const Color(0xFF1B1C1B),
    ),
  );
}

String _asset(String name) => 'assets/images/start/$name.png';
