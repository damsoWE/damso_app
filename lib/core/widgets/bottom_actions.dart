import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 화면 하단에 고정하는 버튼 영역(Figma 각 화면의 `bottom actions`). Scaffold.bottomNavigationBar 에 둔다.
/// 버튼은 위에서 아래로 쌓고, 주 버튼을 맨 아래에 둔다.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
