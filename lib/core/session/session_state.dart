import 'role.dart';

/// 이 기기의 로그인 상태(data-model §1). 라우터 redirect 가 이 값만 보고 이동을 정한다.
sealed class SessionState {
  const SessionState();
}

/// 앱 시작 직후, 저장된 갱신 토큰으로 복구하는 중.
final class SessionChecking extends SessionState {
  const SessionChecking();

  @override
  String toString() => 'SessionChecking';
}

/// 복구 중 네트워크 오류. 저장된 토큰은 지우지 않는다.
final class SessionUnreachable extends SessionState {
  const SessionUnreachable();

  @override
  String toString() => 'SessionUnreachable';
}

/// 세션 없음. [sessionExpired] 면 갱신이 거부되어 로그아웃된 것 → 로그인 화면으로.
final class SignedOut extends SessionState {
  const SignedOut({this.sessionExpired = false});

  final bool sessionExpired;

  @override
  bool operator ==(Object other) =>
      other is SignedOut && other.sessionExpired == sessionExpired;

  @override
  int get hashCode => sessionExpired.hashCode;

  @override
  String toString() => 'SignedOut(sessionExpired: $sessionExpired)';
}

/// 로그인됨. [justSignedUp] 이면 이용 안내(C-6)를 먼저 보여 준다.
final class SignedIn extends SessionState {
  const SignedIn(this.role, {this.justSignedUp = false});

  final Role role;
  final bool justSignedUp;

  @override
  bool operator ==(Object other) =>
      other is SignedIn &&
      other.role == role &&
      other.justSignedUp == justSignedUp;

  @override
  int get hashCode => Object.hash(role, justSignedUp);

  @override
  String toString() => 'SignedIn($role, justSignedUp: $justSignedUp)';
}
