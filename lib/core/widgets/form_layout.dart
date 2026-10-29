import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bottom_actions.dart';

/// 입력 화면 공통 틀: 앱바 + 스크롤 가능한 여백 있는 본문 + 하단 고정 버튼([bottom]).
/// 하단 버튼은 본문 아래에 두어 키보드가 올라오면 함께 올라간다(Figma 각 화면의 `bottom`).
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    this.title,
    required this.children,
    this.leading,
    this.actions,
    this.bottom = const [],
  });

  /// 앱바 제목. null 이면 앱바에 뒤로 아이콘만 둔다(Figma 로그인처럼 본문에 큰 제목이 있는 화면).
  final String? title;
  final List<Widget> children;

  /// 앱바 왼쪽. null 이면 뒤로 갈 화면이 있을 때 기본 뒤로 아이콘.
  final Widget? leading;
  final List<Widget>? actions;

  /// 화면 하단에 고정할 버튼. 위에서 아래로 쌓고 주 버튼을 맨 아래에 둔다.
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: switch (title) {
          final t? => Text(t),
          null => null,
        },
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: children,
              ),
            ),
            if (bottom.isNotEmpty) BottomActions(children: bottom),
          ],
        ),
      ),
    );
  }
}

/// 화면 단위 안내(서버 message 등). null 이면 그리지 않는다.
class MessageText extends StatelessWidget {
  const MessageText(this.message, {super.key, this.isError = true});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.smallStrong.copyWith(
          color: isError ? AppColors.statusUrgentText : AppColors.statusSuccess,
        ),
      ),
    );
  }
}

/// 요청 중이면 진행 표시를 보이는 주 버튼(Figma Button `Primary`·`Loading`). [onPressed] 가 null 이면 비활성.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Figma Button `Danger`(탈퇴처럼 되돌릴 수 없는 동작): 긴급 색 바탕 + 흰 글자.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger ? AppColors.statusUrgent : AppColors.brandPrimary;
    if (!isLoading) {
      return FilledButton(
        onPressed: onPressed,
        style: danger
            ? FilledButton.styleFrom(
                backgroundColor: background,
                foregroundColor: AppColors.textInverse,
              )
            : null,
        child: Text(label),
      );
    }
    // Figma Button `Loading`: 누를 수 없지만 흐리게 하지 않는다.
    return FilledButton(
      onPressed: null,
      style: FilledButton.styleFrom(
        disabledBackgroundColor: background,
        disabledForegroundColor: AppColors.textInverse,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
