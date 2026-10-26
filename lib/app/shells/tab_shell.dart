import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 학부모·교사 공통 하단 탭(홈 · 문의 · 마이페이지, Figma F2-1·F3-4 탭 바).
/// 탭마다 이동 기록을 따로 유지한다(StatefulShellRoute.indexedStack, research R2).
/// 같은 탭을 다시 누르면 그 탭의 처음 화면으로, 다른 탭에서 오면 [onTabEntered] 를 부른다.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.shell, this.onTabEntered});

  final StatefulNavigationShell shell;

  /// 다른 탭에서 [index] 탭으로 들어왔을 때(목록 새로 고침, spec FR-019·FR-020a).
  final void Function(int index)? onTabEntered;

  static const _tabs = [
    (label: '홈', icon: Icons.home_outlined, selected: Icons.home),
    (label: '문의', icon: Icons.chat_bubble_outline, selected: Icons.chat_bubble),
    (label: '마이페이지', icon: Icons.person_outline, selected: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    // 홈이 아닌 탭의 첫 화면에서 뒤로 가면 앱을 닫지 않고 홈 탭으로 간다.
    // 탭 안의 Navigator 가 "뒤로 갈 곳 없음"을 알리면 Android 가 앱을 바로 닫으므로,
    // 홈이 아닌 탭에서는 그 알림을 "처리할 수 있음"으로 바꿔 올려 보낸다.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        shell.goBranch(0);
        onTabEntered?.call(0);
      },
      child: Builder(
        builder: (context) => NotificationListener<NavigationNotification>(
          onNotification: (n) {
            if (shell.currentIndex == 0 || n.canHandlePop) return false;
            const NavigationNotification(canHandlePop: true).dispatch(context);
            return true;
          },
          child: _scaffold(),
        ),
      ),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) {
          final same = index == shell.currentIndex;
          shell.goBranch(index, initialLocation: same);
          if (!same) onTabEntered?.call(index);
        },
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
