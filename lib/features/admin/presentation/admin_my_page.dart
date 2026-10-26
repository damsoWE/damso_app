import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../me/presentation/my_page_parts.dart';

/// ADM-7 마이페이지 (Figma 216-5790). 슈퍼 관리자는 탈퇴 메뉴가 없다(FR-039).
class AdminMyPage extends StatelessWidget {
  const AdminMyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        children: [
          const MeHeader(),
          const Divider(height: 1),
          MenuTile('계정 정보', onTap: () => openAccount(context)),
          MenuTile('비밀번호 재설정', onTap: () => context.push('/password-reset')),
          MenuTile('담소 이용 안내', onTap: () => context.push('/welcome')),
          const LogoutTile(),
        ],
      ),
    );
  }
}
