import 'dart:async';

import 'package:flutter/material.dart';

import '../error/app_exception.dart';
import '../error/error_codes.dart';
import '../theme/app_theme.dart';

/// 대기·잠금 상태 조각(data-model §1 Cooldown). 횟수·시간 규칙은 서버만 안다(research R6).
@immutable
class Cooldown {
  const Cooldown({this.until, this.remaining = Duration.zero});

  static const none = Cooldown();

  /// 다시 시도 가능 시각. null 이면 대기 없음.
  final DateTime? until;

  /// 남은 시간. 0 이면 버튼을 연다.
  final Duration remaining;

  bool get isActive => remaining > Duration.zero;

  @override
  bool operator ==(Object other) =>
      other is Cooldown && other.until == until && other.remaining == remaining;

  @override
  int get hashCode => Object.hash(until, remaining);
}

/// ViewModel 이 쓰는 1초 카운트다운. ViewModel 은 `ref.onDispose(timer.cancel)` 로 정리한다.
/// 남은 시간은 틱마다 1초씩 줄인다(테스트의 가짜 시간과도 맞는다). 앱이 멈춰 틱이 빠졌으면
/// 실제 시각(`until`)으로 맞춘다 — 대기가 최대 1시간이라 백그라운드에서 돌아오면 차이가 크다.
class CooldownTimer {
  CooldownTimer({DateTime Function() now = DateTime.now}) : _now = now;

  final DateTime Function() _now;
  Timer? _timer;

  /// 429(TOO_MANY_ATTEMPTS)면 서버가 준 남은 시간으로 대기를 시작하고 true.
  bool startIfLimited(AppException e, void Function(Cooldown) onTick) {
    if (e.code != ErrorCodes.tooManyAttempts) return false;
    start(e.retryAfter, onTick);
    return true;
  }

  /// [retryAfter] 가 없으면 대기 없이 연다 — 화면은 서버 문구만 보이고 서버가 다시 판단한다(research R6).
  void start(Duration? retryAfter, void Function(Cooldown) onTick) {
    cancel();
    if (retryAfter == null || retryAfter <= Duration.zero) {
      onTick(Cooldown.none);
      return;
    }
    final until = _now().add(retryAfter);
    var remaining = retryAfter;
    onTick(Cooldown(until: until, remaining: remaining));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining -= const Duration(seconds: 1);
      final actual = _ceilToSecond(until.difference(_now()));
      if (actual < remaining) remaining = actual;
      if (remaining <= Duration.zero) {
        cancel();
        onTick(Cooldown.none);
      } else {
        onTick(Cooldown(until: until, remaining: remaining));
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  static Duration _ceilToSecond(Duration d) =>
      Duration(seconds: (d.inMilliseconds / 1000).ceil());
}

/// `h시간 m분 s초`(0인 분·초는 뺀다, 예: `1시간`) / `m분 s초` / `s초`.
String formatRemaining(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = total % 3600 ~/ 60;
  final s = total % 60;
  if (h > 0) return ['$h시간', if (m > 0) '$m분', if (s > 0) '$s초'].join(' ');
  return m > 0 ? '$m분 $s초' : '$s초';
}

/// 남은 시간 안내. 고정 횟수·시간 문구("5회", "10분")는 쓰지 않는다.
class CooldownNotice extends StatelessWidget {
  const CooldownNotice(this.cooldown, {super.key, this.activeText});

  final Cooldown cooldown;

  /// 남은 시간 문자열을 받아 안내 문구를 만든다. 기본: "○초 후에 다시 시도할 수 있습니다."
  final String Function(String remaining)? activeText;

  /// 대기 중일 때만 보인다. 남은 시간이 없는 429 는 화면의 서버 문구만으로 안내한다(같은 문구 반복 방지).
  @override
  Widget build(BuildContext context) {
    if (!cooldown.isActive) return const SizedBox.shrink();
    final remaining = formatRemaining(cooldown.remaining);
    final text = activeText?.call(remaining) ?? '$remaining 후에 다시 시도할 수 있습니다.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        text,
        style: AppTextStyles.smallStrong.copyWith(color: AppColors.statusWarning),
      ),
    );
  }
}
