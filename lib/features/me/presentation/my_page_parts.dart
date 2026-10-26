import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/role.dart';
import '../../../core/theme/app_theme.dart';
import 'me_view_model.dart';

/// 역할별 마이페이지(F2-7·F3-7·ADM-7)가 함께 쓰는 조각.
String roleLabel(Role role) => switch (role) {
  Role.parent => '학부모',
  Role.teacher => '교사',
  Role.superAdmin => '관리자',
};

/// 본인 이름·이메일·역할. [extra] 에 연결된 학급 정보를 덧붙인다.
class MeHeader extends ConsumerWidget {
  const MeHeader({super.key, this.extra});

  final String? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meViewModelProvider).value?.me;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: me == null
          ? const SizedBox(height: 48)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${me.name} · ${roleLabel(me.role)}', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(me.email, style: AppTextStyles.small),
                if (extra != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(extra!, style: AppTextStyles.small),
                ],
              ],
            ),
    );
  }
}

class MenuTile extends StatelessWidget {
  const MenuTile(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

/// 계정 정보 · 비밀번호 변경 · 약관 등 공통 메뉴로 이동.
void openAccount(BuildContext context) => context.push('/me/account');

/// 로그아웃: 이 기기만. 이동은 라우터 redirect 가 맡는다.
class LogoutTile extends ConsumerWidget {
  const LogoutTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    title: const Text('로그아웃'),
    onTap: ref.read(meViewModelProvider.notifier).logout,
  );
}
