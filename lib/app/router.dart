import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/role.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../features/admin/presentation/admin_home_page.dart';
import '../features/admin/presentation/admin_my_page.dart';
import '../features/admin/presentation/classroom_detail_page.dart';
import '../features/admin/presentation/classroom_detail_view_model.dart';
import '../features/admin/presentation/classroom_new_page.dart';
import '../features/admin/presentation/invite_codes_page.dart';
import '../features/admin/presentation/invite_issued_page.dart';
import '../features/admin/presentation/reissue_confirm_page.dart';
import '../features/admin/presentation/students_new_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/password_reset/code_page.dart';
import '../features/auth/presentation/password_reset/done_page.dart';
import '../features/auth/presentation/password_reset/email_page.dart';
import '../features/auth/presentation/password_reset/new_password_page.dart';
import '../features/auth/presentation/signup/account_page.dart';
import '../features/auth/presentation/signup/invite_code_page.dart';
import '../features/auth/presentation/signup/verify_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/start_page.dart';
import '../features/auth/presentation/terms_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/inquiry/presentation/parent/compose_page.dart';
import '../features/inquiry/presentation/parent/parent_inquiries_page.dart';
import '../features/inquiry/presentation/parent/submitted_page.dart';
import '../features/inquiry/presentation/parent/urgent_notice_page.dart';
import '../features/inquiry/presentation/teacher/pending_detail_page.dart';
import '../features/inquiry/presentation/teacher/teacher_inquiries_page.dart';
import '../features/inquiry/presentation/teacher/urgent_detail_page.dart';
import '../features/me/presentation/account_page.dart';
import '../features/notification/presentation/settings_page.dart';
import '../features/parent/domain/child.dart';
import '../features/me/presentation/withdraw_page.dart';
import '../features/parent/presentation/add_child_page.dart';
import '../features/parent/presentation/child_select_page.dart';
import '../features/parent/presentation/children_page.dart';
import '../features/parent/presentation/parent_home_page.dart';
import '../features/parent/presentation/parent_my_page.dart';
import '../features/teacher/presentation/links_page.dart';
import '../features/teacher/presentation/profile_edit_page.dart';
import '../features/teacher/presentation/teacher_home_page.dart';
import '../features/teacher/presentation/teacher_my_page.dart';
import 'shells/parent_shell.dart';
import 'shells/teacher_shell.dart';

/// 화면 경로 정의. 화면 트리는 docs/ia.md, 접근 규칙은
/// specs/001-foundation-auth-signup/contracts/routes.md 와
/// specs/002-inquiry-intake-urgent/contracts/routes.md(하단 탭) 와 일치시킨다.
/// 화면 접근 제어는 [resolveRedirect] 한 곳에서만 한다. 권한의 최종 판단은 서버다.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (_, state) =>
        resolveRedirect(ref.read(sessionControllerProvider), state.uri.path),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/', builder: (_, _) => const StartPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      // 가입 화면은 한 경로 아래 쌓여 있는 동안 signupViewModelProvider 가 유지된다.
      GoRoute(
        path: '/signup',
        builder: (_, _) => const InviteCodePage(),
        routes: [
          GoRoute(
            path: 'account',
            builder: (_, _) => const SignupAccountPage(),
          ),
          GoRoute(path: 'verify', builder: (_, _) => const SignupVerifyPage()),
        ],
      ),
      // 로그인·비로그인 모두 접근 가능(마이페이지 "비밀번호 변경").
      GoRoute(
        path: '/password-reset',
        builder: (_, _) => const ResetEmailPage(),
        routes: [
          GoRoute(path: 'code', builder: (_, _) => const ResetCodePage()),
          GoRoute(path: 'new', builder: (_, _) => const ResetNewPasswordPage()),
          GoRoute(path: 'done', builder: (_, _) => const ResetDonePage()),
        ],
      ),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/terms', builder: (_, _) => const TermsPage()),
      // 탭 위에 띄우는 화면(탭 바를 가림). 셸보다 먼저 두어 먼저 맞춘다.
      GoRoute(
        path: '/parent/children/add',
        builder: (_, _) => const AddChildPage(),
      ),
      // 대상 자녀·안내 결과는 extra 로만 받는다. 없으면(재시작·딥링크) 탭 화면으로.
      GoRoute(
        path: '/parent/inquiries/new',
        redirect: (_, s) => s.extra is Child ? null : '/parent',
        builder: (_, s) => ComposePage(child: s.extra! as Child),
      ),
      GoRoute(
        path: '/parent/inquiries/submitted',
        redirect: (_, s) => s.extra is SubmittedArgs ? null : '/parent/inquiries',
        builder: (_, s) => SubmittedPage(args: s.extra! as SubmittedArgs),
      ),
      GoRoute(
        path: '/parent/inquiries/:inquiryId/urgent',
        builder: (_, s) =>
            UrgentNoticePage(inquiryId: s.pathParameters['inquiryId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ParentShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/parent',
                builder: (_, _) => const ParentHomePage(),
                routes: [
                  GoRoute(
                    path: 'children/select',
                    builder: (_, _) => const ChildSelectPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/parent/inquiries',
                builder: (_, _) => const ParentInquiriesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/parent/me', builder: (_, _) => const ParentMyPage()),
              GoRoute(
                path: '/parent/children',
                builder: (_, _) => const ChildrenPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/urgent',
        builder: (_, s) =>
            UrgentDetailPage(inquiryId: s.pathParameters['inquiryId']!),
      ),
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/pending',
        builder: (_, s) =>
            PendingDetailPage(inquiryId: s.pathParameters['inquiryId']!),
      ),
      GoRoute(
        path: '/teacher/settings/notifications',
        builder: (_, _) => const SettingsPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TeacherShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/teacher', builder: (_, _) => const TeacherHomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/inquiries',
                builder: (_, _) => const TeacherInquiriesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/teacher/me', builder: (_, _) => const TeacherMyPage()),
              GoRoute(
                path: '/teacher/profile',
                builder: (_, _) => const ProfileEditPage(),
              ),
              GoRoute(path: '/teacher/links', builder: (_, _) => const LinksPage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (_, _) => const AdminHomePage(),
        routes: [
          // 'new' 가 :classroomId 로 잡히지 않도록 먼저 둔다.
          GoRoute(
            path: 'classrooms/new',
            builder: (_, _) => const ClassroomNewPage(),
          ),
          GoRoute(
            path: 'classrooms/:classroomId',
            builder: (_, s) =>
                ClassroomDetailPage(classroomId: s.pathParameters['classroomId']!),
            routes: [
              GoRoute(
                path: 'students/new',
                builder: (_, s) => StudentsNewPage(
                  classroomId: s.pathParameters['classroomId']!,
                ),
              ),
              GoRoute(
                path: 'invite-codes',
                builder: (_, s) => InviteCodesPage(
                  classroomId: s.pathParameters['classroomId']!,
                ),
              ),
            ],
          ),
          // 대상·코드는 extra 로만 전달한다(URL 에 이름·코드 원문을 넣지 않음).
          GoRoute(
            path: 'invite/confirm',
            builder: (_, s) =>
                ReissueConfirmPage(target: s.extra as InviteTarget?),
          ),
          GoRoute(
            path: 'invite/issued',
            builder: (_, s) =>
                InviteIssuedPage(args: s.extra as IssuedInviteArgs?),
          ),
          GoRoute(path: 'me', builder: (_, _) => const AdminMyPage()),
        ],
      ),
      GoRoute(path: '/me/account', builder: (_, _) => const AccountPage()),
      GoRoute(path: '/me/withdraw', builder: (_, _) => const WithdrawPage()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// 탭 위에 화면을 띄울 때 쓰는 루트 Navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

bool _under(String location, String prefix) =>
    location == prefix || location.startsWith('$prefix/');

/// 로그아웃 상태에서 열리는 경로.
bool _isPublic(String location) =>
    location == '/' ||
    location == '/login' ||
    location == '/terms' ||
    _under(location, '/signup') ||
    _under(location, '/password-reset');

/// 로그인하면 역할 홈으로 보내는 경로.
bool _isPublicOnly(String location) =>
    location == '/' ||
    location == '/login' ||
    location == '/splash' ||
    _under(location, '/signup');

Role? _ownerOf(String location) {
  if (_under(location, '/parent')) return Role.parent;
  if (_under(location, '/teacher')) return Role.teacher;
  if (_under(location, '/admin')) return Role.superAdmin;
  return null;
}

/// contracts/routes.md "redirect 규칙". null 이면 그대로 둔다.
@visibleForTesting
String? resolveRedirect(SessionState state, String location) {
  switch (state) {
    case SessionChecking() || SessionUnreachable():
      return location == '/splash' ? null : '/splash';
    case SignedOut(:final sessionExpired):
      if (_isPublic(location)) return null;
      return sessionExpired ? '/login' : '/';
    case SignedIn(:final role, :final justSignedUp):
      if (justSignedUp) return location == '/welcome' ? null : '/welcome';
      final home = role.homePath;
      if (_isPublicOnly(location)) return home;
      final owner = _ownerOf(location);
      if (owner != null && owner != role) return home;
      // 옛 문의 경로 → 역할 문의 탭(specs/002 routes.md 규칙 4-b, FR-032).
      if (_under(location, '/inquiries')) {
        return switch (role) {
          Role.parent => '/parent/inquiries',
          Role.teacher => '/teacher/inquiries',
          Role.superAdmin => '/admin', // FR-037
        };
      }
      if (role == Role.superAdmin && location == '/me/withdraw') {
        return '/admin/me';
      }
      return null;
  }
}
