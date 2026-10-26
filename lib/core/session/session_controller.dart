import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_store.dart';
import 'role.dart';
import 'session_state.dart';

/// 세션 상태를 쥐는 단일 지점. 라우터 redirect 와 AuthInterceptor 가 이 값을 쓴다.
/// 역할·이메일은 저장하지 않는다(research R2).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionChecking();

  void signIn(Role role, {bool justSignedUp = false}) {
    state = SignedIn(role, justSignedUp: justSignedUp);
  }

  /// 이용 안내(C-6) 확인. justSignedUp 만 내린다.
  void acknowledgeWelcome() {
    final s = state;
    if (s is SignedIn && s.justSignedUp) state = SignedIn(s.role);
  }

  void markUnreachable() => state = const SessionUnreachable();

  void retryRestore() => state = const SessionChecking();

  /// 로그아웃·탈퇴·비밀번호 재설정 완료 → 시작 화면.
  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).clear();
    state = const SignedOut();
  }

  /// 갱신 거부 → 로그인 화면(constitution "갱신이 실패하면 … 로그인 화면으로").
  Future<void> expire() async {
    if (state is SignedOut) return;
    await ref.read(tokenStoreProvider).clear();
    state = const SignedOut(sessionExpired: true);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
