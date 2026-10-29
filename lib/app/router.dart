import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/role.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../core/theme/app_theme.dart';
import '../core/util/uuid.dart';
import '../features/admin/presentation/admin_home_page.dart';
import '../features/admin/presentation/admin_my_page.dart';
import '../features/admin/presentation/classroom_detail_page.dart';
import '../features/admin/presentation/classroom_detail_view_model.dart';
import '../features/admin/presentation/classroom_new_page.dart';
import '../features/admin/presentation/inquiry_status_page.dart';
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
import '../features/inquiry/domain/models.dart';
import '../features/inquiry/presentation/parent/compose_page.dart';
import '../features/inquiry/presentation/parent/parent_inquiries_page.dart';
import '../features/inquiry/presentation/parent/submitted_page.dart';
import '../features/inquiry/presentation/parent/urgent_notice_page.dart';
import '../features/inquiry/presentation/teacher/content_page.dart';
import '../features/inquiry/presentation/teacher/general_detail_page.dart';
import '../features/inquiry/presentation/teacher/teacher_inquiries_page.dart';
import '../features/inquiry/presentation/teacher/urgent_detail_page.dart';
import '../features/reply/domain/models.dart';
import '../features/reply/presentation/answer_compose_page.dart';
import '../features/reply/presentation/follow_up_detail_page.dart';
import '../features/reply/presentation/thread_page.dart';
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
import 'shells/admin_shell.dart';
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
    // 없는 경로는 go_router 기본 오류 화면(예외 문구 노출) 대신 고정 안내로 보인다.
    errorBuilder: (_, _) => const _NotFoundPage(),
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
      // 일반 문의 상세(F3-2·F3-3·F3-3a·정리 중)와 원문 열람(F3-6), specs/003 contracts/routes.md.
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/general',
        builder: (_, s) =>
            GeneralDetailPage(inquiryId: s.pathParameters['inquiryId']!),
      ),
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/content',
        builder: (_, s) => ContentPage(
          inquiryId: s.pathParameters['inquiryId']!,
          summary: s.extra is TeacherInquirySummary ? s.extra as TeacherInquirySummary : null,
          args: s.extra is ContentArgs ? s.extra as ContentArgs : null,
        ),
      ),
      // 답변 작성(F4-2a~F4-2h)·스레드(F4-3), specs/004 contracts/routes.md.
      // :inquiryId 는 스레드 루트 ID. 머리 정보는 extra 로만 받는다(URL 에 이름·제목을 넣지 않음).
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/answer',
        redirect: (_, s) => s.extra is AnswerTarget ? null : '/teacher/inquiries',
        builder: (_, s) => AnswerComposePage(target: s.extra! as AnswerTarget),
      ),
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/thread',
        builder: (_, s) => ThreadPage(inquiryId: s.pathParameters['inquiryId']!),
      ),
      // 재문의 상세(F4-3b, research R13). 재문의 정보는 스레드가 extra 로 넘긴다. 없으면 스레드로.
      // 경로 ID 가 UUID 가 아니면 이 redirect 전에 resolveRedirect 가 목록으로 보낸다.
      GoRoute(
        path: '/teacher/inquiries/:inquiryId/follow-ups/:followUpId',
        redirect: (_, s) => s.extra is FollowUpArgs
            ? null
            : '/teacher/inquiries/${s.pathParameters['inquiryId']}/thread',
        builder: (_, s) => FollowUpDetailPage(args: s.extra! as FollowUpArgs),
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
      // 관리자: 탭 위에 띄우는 화면(경로 문자열은 그대로, specs/006 contracts/routes.md).
      // 'new' 가 :classroomId 로 잡히지 않도록 먼저 둔다.
      GoRoute(
        path: '/admin/classrooms/new',
        builder: (_, _) => const ClassroomNewPage(),
      ),
      GoRoute(
        path: '/admin/classrooms/:classroomId',
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
        path: '/admin/invite/confirm',
        builder: (_, s) => ReissueConfirmPage(target: s.extra as InviteTarget?),
      ),
      GoRoute(
        path: '/admin/invite/issued',
        builder: (_, s) => InviteIssuedPage(args: s.extra as IssuedInviteArgs?),
      ),
      // 관리자 탭: 홈 · 문의(ADM-4 문의 현황) · 마이페이지(specs/006 research R3).
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AdminShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/admin', builder: (_, _) => const AdminHomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/inquiries',
                builder: (_, _) => const InquiryStatusPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/admin/me', builder: (_, _) => const AdminMyPage()),
            ],
          ),
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

/// ID 를 경로에 담는 화면(문의·재문의·학급)의 ID 가 모두 UUID 인지.
/// [location] 은 디코딩 전 경로라 `%2F`·`%2e%2e` 가 섞이면 한 칸이 UUID 모양이 아니게 된다.
bool _hasValidIds(String location) {
  final s = location.split('/'); // ['', 'teacher', 'inquiries', <id>, <화면>, ...]
  if (s.length < 4) return true;
  switch (s[1]) {
    case 'parent' || 'teacher':
      if (s[2] != 'inquiries' || s.length < 5) return true; // new·submitted 등
      if (!isUuid(s[3])) return false;
      return s.length < 6 || s[4] != 'follow-ups' || isUuid(s[5]);
    case 'admin':
      if (s[2] != 'classrooms' || s[3] == 'new') return true;
      return isUuid(s[3]);
  }
  return true;
}

/// 없는 경로로 들어왔을 때의 고정 안내. 예외 내용은 보이지 않는다.
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '페이지를 찾을 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.md),
                // /splash 는 redirect 가 역할 홈(로그아웃이면 시작 화면)으로 보낸다.
                FilledButton(
                  onPressed: () => context.go('/splash'),
                  child: const Text('처음으로'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      // 경로 ID 는 API 경로에 그대로 끼워 넣어지므로 UUID 가 아니면 화면을 열지 않는다.
      if (!_hasValidIds(location)) {
        return switch (role) {
          Role.parent => '/parent/inquiries',
          Role.teacher => '/teacher/inquiries',
          Role.superAdmin => '/admin',
        };
      }
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
