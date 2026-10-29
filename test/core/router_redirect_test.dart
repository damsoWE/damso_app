import 'package:damso_app/app/router.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

/// 등록된 모든 경로 문자열(셸 안 경로 포함, 하위 경로는 부모 경로를 붙여서).
List<String> _allPaths(List<RouteBase> routes, [String parent = '']) => [
  for (final r in routes)
    if (r is GoRoute) ...[
      r.path.startsWith('/') ? r.path : '$parent/${r.path}',
      ..._allPaths(r.routes, r.path.startsWith('/') ? r.path : '$parent/${r.path}'),
    ] else if (r is ShellRouteBase)
      ..._allPaths(r.routes, parent),
];

const _publicPaths = [
  '/',
  '/login',
  '/signup',
  '/signup/account',
  '/signup/verify',
  '/password-reset',
  '/password-reset/code',
  '/password-reset/new',
  '/password-reset/done',
  '/terms',
];

const _home = {
  Role.parent: '/parent',
  Role.teacher: '/teacher',
  Role.superAdmin: '/admin',
};

/// 역할별 전용 경로 예시 (contracts/routes.md).
const _rolePaths = {
  Role.parent: [
    '/parent',
    '/parent/children',
    '/parent/children/add',
    '/parent/me',
    '/parent/inquiries',
    '/parent/inquiries/new',
    '/parent/inquiries/submitted',
    '/parent/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/urgent',
  ],
  Role.teacher: [
    '/teacher',
    '/teacher/me',
    '/teacher/profile',
    '/teacher/links',
    '/teacher/inquiries',
    '/teacher/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/urgent',
    '/teacher/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/general',
    '/teacher/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/content',
    '/teacher/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/answer',
    '/teacher/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/thread',
    '/teacher/inquiries/9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a/follow-ups/1f0e9d8c-7b6a-4d3c-8b2a-9d8c7b6a5f4e',
    '/teacher/settings/notifications',
  ],
  Role.superAdmin: [
    '/admin',
    '/admin/classrooms/new',
    '/admin/classrooms/3f2c9a1e-8b7d-4c5e-9f0a-1b2c3d4e5f60',
    '/admin/invite/issued',
    '/admin/me',
    '/admin/inquiries', // ADM-4 문의 현황(specs/006)
  ],
};

void main() {
  // 감사 기록 조회는 서버 운영자 전용, 내보내기는 MVP 제외(specs/006 FR-009, SC-004).
  testWidgets('감사 기록을 보거나 내보내는 화면 경로가 없다', (tester) async {
    await tester.pumpWidget(testApp());
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    final paths = _allPaths(router.configuration.routes);
    expect(paths, contains('/admin/inquiries')); // 목록이 제대로 모였는지
    final segments = {for (final p in paths) ...p.split('/')};
    for (final word in ['audit', 'audit-logs', 'logs', 'history', 'export']) {
      expect(segments, isNot(contains(word)), reason: word);
    }
  });

  group('확인 중·연결 불가', () {
    for (final state in const [SessionChecking(), SessionUnreachable()]) {
      test('$state 는 어디서든 /splash', () {
        expect(resolveRedirect(state, '/'), '/splash');
        expect(resolveRedirect(state, '/parent'), '/splash');
        expect(resolveRedirect(state, '/splash'), isNull);
      });
    }
  });

  group('로그아웃', () {
    test('공개 경로는 그대로', () {
      for (final path in _publicPaths) {
        expect(resolveRedirect(const SignedOut(), path), isNull, reason: path);
      }
    });

    test('보호 경로·splash 는 시작 화면으로', () {
      for (final path in ['/splash', '/parent', '/admin/me', '/me/account', '/welcome', '/inquiries']) {
        expect(resolveRedirect(const SignedOut(), path), '/', reason: path);
      }
    });

    test('갱신 거부로 로그아웃되면 보호 경로·splash 는 로그인 화면으로', () {
      const expired = SignedOut(sessionExpired: true);
      for (final path in ['/splash', '/parent', '/teacher/links', '/me/account']) {
        expect(resolveRedirect(expired, path), '/login', reason: path);
      }
      for (final path in _publicPaths) {
        expect(resolveRedirect(expired, path), isNull, reason: path);
      }
    });
  });

  group('로그인', () {
    test('가입 직후에는 이용 안내를 먼저 본다', () {
      const state = SignedIn(Role.parent, justSignedUp: true);
      expect(resolveRedirect(state, '/parent'), '/welcome');
      expect(resolveRedirect(state, '/signup/verify'), '/welcome');
      expect(resolveRedirect(state, '/welcome'), isNull);
    });

    for (final role in Role.values) {
      final state = SignedIn(role);
      final home = _home[role]!;

      test('$role: 공개 전용 경로는 역할 홈으로', () {
        for (final path in ['/', '/login', '/signup', '/signup/account', '/splash']) {
          expect(resolveRedirect(state, path), home, reason: path);
        }
      });

      test('$role: 자기 역할 경로는 그대로', () {
        for (final path in _rolePaths[role]!) {
          expect(resolveRedirect(state, path), isNull, reason: path);
        }
      });

      test('$role: 다른 역할 경로는 자기 역할 홈으로 (SC-002)', () {
        for (final other in Role.values.where((r) => r != role)) {
          for (final path in _rolePaths[other]!) {
            expect(resolveRedirect(state, path), home, reason: path);
          }
        }
      });

      test('$role: 공통 경로는 그대로', () {
        for (final path in ['/password-reset', '/password-reset/done', '/terms', '/me/account', '/welcome']) {
          expect(resolveRedirect(state, path), isNull, reason: path);
        }
      });
    }

    test('슈퍼 관리자는 탈퇴 화면 대신 관리자 마이페이지로', () {
      expect(resolveRedirect(const SignedIn(Role.superAdmin), '/me/withdraw'), '/admin/me');
      expect(resolveRedirect(const SignedIn(Role.parent), '/me/withdraw'), isNull);
      expect(resolveRedirect(const SignedIn(Role.teacher), '/me/withdraw'), isNull);
    });

    test('옛 경로 /inquiries 는 역할 문의 탭으로, 슈퍼 관리자는 관리자 홈으로 (FR-032, FR-037)', () {
      for (final path in ['/inquiries', '/inquiries/abc']) {
        expect(resolveRedirect(const SignedIn(Role.parent), path), '/parent/inquiries');
        expect(resolveRedirect(const SignedIn(Role.teacher), path), '/teacher/inquiries');
        expect(resolveRedirect(const SignedIn(Role.superAdmin), path), '/admin');
      }
    });
  });
}
