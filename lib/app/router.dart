import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/inquiry/presentation/inquiry_list_page.dart';

/// 화면 경로 정의. 화면 트리는 docs/ia.md 와 일치시킨다.
/// 로그인 여부에 따른 redirect(가드)는 인증 기능 구현 시 추가한다.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/inquiries', builder: (_, _) => const InquiryListPage()),
    ],
  );
});
