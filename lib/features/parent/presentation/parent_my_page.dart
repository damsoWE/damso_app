import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../me/presentation/my_page_parts.dart';
import 'children_view_model.dart';

/// F2-7 마이페이지 (Figma 224-1228). 알림 설정 메뉴는 F2 에서 추가한다.
class ParentMyPage extends ConsumerWidget {
  const ParentMyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenViewModelProvider).value;
    final classes = children
        ?.map((c) => '${c.studentName} ${c.classroom.grade}학년 ${c.classroom.classNumber}반')
        .join(' · ');
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        children: [
          MeHeader(extra: classes == null || classes.isEmpty ? null : classes),
          const Divider(height: 1),
          MenuTile('계정 정보', onTap: () => openAccount(context)),
          MenuTile('연결된 자녀', onTap: () => context.push('/parent/children')),
          MenuTile('비밀번호 변경', onTap: () => context.push('/password-reset')),
          MenuTile('이용약관 · 개인정보 처리방침', onTap: () => context.push('/terms')),
          const LogoutTile(),
          MenuTile('회원 탈퇴', onTap: () => context.push('/me/withdraw')),
        ],
      ),
    );
  }
}
