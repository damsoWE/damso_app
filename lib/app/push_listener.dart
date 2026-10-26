import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/pending_navigation.dart';
import '../core/push/push_messaging.dart';
import '../core/push/push_messaging_provider.dart';
import '../core/session/role.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import '../features/notification/presentation/device_registrar.dart';
import 'router.dart';

/// 앱 안 배너를 띄울 ScaffoldMessenger.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 기기 알림 수신·이동(research R9). 로그인 전에도 알림을 눌러 열 수 있으므로
/// 교사 탭 셸이 아니라 앱 루트에서 듣는다.
/// - 열린 상태 수신: 교사면 앱 안 배너(서버 고정 문구) + 교사 문의 목록 새로 고침(FR-020a)
/// - 알림으로 열기: 교사로 로그인돼 있으면 바로 이동, 로그인 전이면 로그인 뒤 이동(FR-031b)
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

  bool get _isTeacher {
    final s = ref.read(sessionControllerProvider);
    return s is SignedIn && s.role == Role.teacher;
  }

  void _onForeground(PushMessage message) {
    if (!_isTeacher) return;
    ref.read(teacherInquiriesViewModelProvider.notifier).refresh();
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentMaterialBanner()
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
    if (_isTeacher) {
      ref.read(routerProvider).push(data.route);
    } else if (session is! SignedIn) {
      // 로그인(또는 세션 복구) 뒤 교사면 교사 탭 셸이 이 경로를 띄운다.
      ref.read(pendingNavigationProvider.notifier).set(data.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(deviceRegistrarProvider); // 세션 변화에 따라 기기 등록·해제
    // 알림으로 연 경로는 교사(가입 직후 제외)만 쓴다. 그 밖의 로그인이면 버린다.
    // 교사면 교사 탭 셸이 뜬 뒤 그 위에 띄운다(TeacherShell).
    ref.listen(sessionControllerProvider, (_, next) {
      if (next is! SignedIn) return;
      if (next.role != Role.teacher || next.justSignedUp) {
        ref.read(pendingNavigationProvider.notifier).clear();
      }
    });
    return widget.child;
  }
}
