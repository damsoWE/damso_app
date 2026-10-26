import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 대기·잠금 상태 조각(data-model §1 Cooldown). 횟수·시간 규칙은 서버만 안다(research R6).
@immutable
class Cooldown {
  const Cooldown({
    this.until,
    this.remaining = Duration.zero,
    this.unknownDuration = false,
  });

  static const none = Cooldown();

  /// 다시 시도 가능 시각. null 이면 대기 없음.
  final DateTime? until;

  /// 남은 시간. 0 이면 버튼을 연다.
  final Duration remaining;

  /// 서버가 남은 시간을 주지 않은 잠금. 일반 안내만 보이고 버튼은 바로 연다.
  final bool unknownDuration;

  bool get isActive => remaining > Duration.zero;

  @override
  bool operator ==(Object other) =>
      other is Cooldown &&
      other.until == until &&
      other.remaining == remaining &&
      other.unknownDuration == unknownDuration;

  @override
  int get hashCode => Object.hash(until, remaining, unknownDuration);
}

/// ViewModel 이 쓰는 1초 카운트다운. ViewModel 은 `ref.onDispose(timer.cancel)` 로 정리한다.
/// 남은 시간은 틱마다 1초씩 줄인다(테스트의 가짜 시간과도 맞는다).
class CooldownTimer {
  Timer? _timer;

  void start(Duration? retryAfter, void Function(Cooldown) onTick) {
    cancel();
    if (retryAfter == null || retryAfter <= Duration.zero) {
      onTick(const Cooldown(unknownDuration: true));
      return;
    }
    final until = DateTime.now().add(retryAfter);
    var remaining = retryAfter;
    onTick(Cooldown(until: until, remaining: remaining));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining -= const Duration(seconds: 1);
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
}

/// `m분 s초` / `s초`.
String formatRemaining(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return m > 0 ? '$m분 $s초' : '$s초';
}

/// 남은 시간 안내. 고정 횟수·시간 문구("5회", "10분")는 쓰지 않는다.
class CooldownNotice extends StatelessWidget {
  const CooldownNotice(this.cooldown, {super.key, this.activeText});

  final Cooldown cooldown;

  /// 남은 시간 문자열을 받아 안내 문구를 만든다. 기본: "○초 후에 다시 시도할 수 있습니다."
  final String Function(String remaining)? activeText;

  @override
  Widget build(BuildContext context) {
    final String? text;
    if (cooldown.isActive) {
      final remaining = formatRemaining(cooldown.remaining);
      text = activeText?.call(remaining) ?? '$remaining 후에 다시 시도할 수 있습니다.';
    } else if (cooldown.unknownDuration) {
      text = '잠시 후 다시 시도해 주세요.';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        text,
        style: AppTextStyles.smallStrong.copyWith(color: AppColors.statusWarning),
      ),
    );
  }
}
