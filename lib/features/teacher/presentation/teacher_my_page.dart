import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../me/presentation/my_page_parts.dart';
import 'links_view_model.dart';

/// F3-7 마이페이지 (Figma 224-1263). 응답 가능 시간·알림 메뉴는 F2 에서 추가한다.
class TeacherMyPage extends ConsumerWidget {
  const TeacherMyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 담당 학급이 없으면(403) 학급 표시를 생략한다.
    final classroom = ref.watch(linksViewModelProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        children: [
          MeHeader(
            extra: classroom == null
                ? null
                : '담당 ${classroom.grade}학년 ${classroom.classNumber}반',
          ),
          const Divider(height: 1),
          MenuTile('계정 정보', onTap: () => openAccount(context)),
          MenuTile('공개 프로필', onTap: () => context.push('/teacher/profile')),
          MenuTile('학부모 연결 현황', onTap: () => context.push('/teacher/links')),
          MenuTile(
            '응답 가능 시간 · 알림',
            onTap: () => context.push('/teacher/settings/notifications'),
          ),
          MenuTile('비밀번호 변경', onTap: () => context.push('/password-reset')),
          MenuTile('이용약관 · 개인정보 처리방침', onTap: () => context.push('/terms')),
          const LogoutTile(),
          MenuTile('회원 탈퇴', onTap: () => context.push('/me/withdraw')),
        ],
      ),
    );
  }
}
