import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// 전화 걸기 화면 열기(research R11). 번호가 입력된 다이얼 화면만 열고 직접 걸지 않는다.
/// 위젯 테스트는 [dialLauncherProvider] 를 가짜로 바꾼다.
abstract class DialLauncher {
  Future<bool> canDial();

  Future<void> dial(String number);
}

class UrlDialLauncher implements DialLauncher {
  const UrlDialLauncher();

  static Uri _uri(String number) => Uri(scheme: 'tel', path: number);

  @override
  Future<bool> canDial() => canLaunchUrl(_uri('112'));

  @override
  Future<void> dial(String number) => launchUrl(_uri(number));
}

final dialLauncherProvider = Provider<DialLauncher>(
  (_) => const UrlDialLauncher(),
);

/// 이 기기에서 전화 걸기 화면을 열 수 있는지(태블릿 등은 false).
final canDialProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(dialLauncherProvider).canDial(),
);
