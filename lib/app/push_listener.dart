import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/pending_navigation.dart';
import '../core/push/push_messaging.dart';
import '../core/push/push_messaging_provider.dart';
import '../core/session/role.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../features/inquiry/presentation/parent/parent_inquiries_view_model.dart';
import '../features/inquiry/presentation/parent/thread_view_model.dart';
import '../features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import '../features/notification/presentation/device_registrar.dart';
import 'router.dart';

/// 앱 안 배너를 띄울 ScaffoldMessenger.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 기기 알림 수신·이동(research R9). 로그인 전에도 알림을 눌러 열 수 있으므로
/// 교사 탭 셸이 아니라 앱 루트에서 듣는다.
/// 알림은 종류마다 받을 역할이 있고(교사: 긴급·일반, 학부모: 답변), 로그인한 역할과 같을 때만 처리한다
/// (specs/007 R7, FR-020).
/// - 열린 상태 수신: 앱 안 배너(서버 고정 문구) + 그 역할의 문의 목록·스레드 새로 고침(FR-020a, 007 FR-019)
/// - 알림으로 열기: 같은 역할로 로그인돼 있으면 바로 이동, 로그인 전이면 로그인 뒤 이동(FR-031b)
class PushListener extends ConsumerStatefulWidget {
  const PushListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends ConsumerState<PushListener> {
  final _subs = <StreamSubscription<Object?>>[];
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 등록 실패·뒤늦은 권한 허용은 앱이 다시 앞으로 올 때 다시 시도한다.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(deviceRegistrarProvider).onResume(),
    );
    final push = ref.read(pushMessagingProvider);
    _subs
      ..add(push.onForegroundMessage.listen(_onForeground))
      ..add(push.onMessageOpened.listen(_open));
    push.initialMessage().then((data) {
      if (data != null && mounted) _open(data);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  PushTarget? get _roleTarget {
    final s = ref.read(sessionControllerProvider);
    if (s is! SignedIn) return null;
    return switch (s.role) {
      Role.teacher => PushTarget.teacher,
      Role.parent => PushTarget.parent,
      Role.superAdmin => null,
    };
  }

  void _refreshFor(PushData data) {
    switch (data.target) {
      case PushTarget.teacher:
        ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
      case PushTarget.parent:
        ref.invalidate(parentInquiriesViewModelProvider);
        final id = data.inquiryId;
        if (id != null) ref.invalidate(parentThreadViewModelProvider(id));
      case null:
        break;
    }
  }

  void _onForeground(PushMessage message) {
    final target = message.data.target;
    if (target == null || target != _roleTarget) return;
    _refreshFor(message.data);
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      // 대기열에 남은 이전 배너가 최신(긴급일 수 있는) 배너를 가리지 않도록 비운다.
      ..clearMaterialBanners()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(
            message.body.isEmpty ? message.title : '${message.title}\n${message.body}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                _open(message.data);
              },
              child: const Text('보기'),
            ),
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('닫기'),
            ),
          ],
        ),
      );
  }

  void _open(PushData data) {
    final session = ref.read(sessionControllerProvider);
    final target = data.target;
    if (target == null) return;
    if (target == _roleTarget) {
      ref.read(routerProvider).push(data.route);
    } else if (session is! SignedIn) {
      // 로그인(또는 세션 복구) 뒤 같은 역할이면 탭 셸이 이 경로를 띄운다.
      ref.read(pendingNavigationProvider.notifier).set(data.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(deviceRegistrarProvider); // 세션 변화에 따라 기기 등록·해제
    // 알림으로 연 경로는 그 경로의 역할(가입 직후 제외)만 쓴다. 그 밖의 로그인이면 버린다.
    // 같은 역할이면 탭 셸이 뜬 뒤 그 위에 띄운다(TeacherShell·ParentShell).
    ref.listen(sessionControllerProvider, (prev, next) {
      // 로그아웃·만료로 세션이 끝나면 앞 사용자가 누른 알림 경로를 비운다.
      // 로그인 전에 알림을 눌러 경로가 담기는 것은 정상이므로 로그인 → 로그아웃 전환에서만 비운다.
      if (prev is SignedIn && next is SignedOut) {
        ref.read(pendingNavigationProvider.notifier).clear();
        return;
      }
      if (next is! SignedIn) return;
      final pending = ref.read(pendingNavigationProvider);
      if (pending == null) return;
      final owner = pending.startsWith('/parent/') ? Role.parent : Role.teacher;
      if (next.role != owner || next.justSignedUp) {
        ref.read(pendingNavigationProvider.notifier).clear();
      }
    });
    return widget.child;
  }
}
