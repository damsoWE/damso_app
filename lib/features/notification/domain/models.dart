/// 교사 응답 가능 시간·알림 설정(specs/002 data-model §4). 한국 시간 기준.
library;

enum DayOfWeek {
  monday('MONDAY', '월'),
  tuesday('TUESDAY', '화'),
  wednesday('WEDNESDAY', '수'),
  thursday('THURSDAY', '목'),
  friday('FRIDAY', '금'),
  saturday('SATURDAY', '토'),
  sunday('SUNDAY', '일');

  const DayOfWeek(this.serverValue, this.label);

  final String serverValue;
  final String label;

  static DayOfWeek fromServer(String value) => values.firstWhere(
    (d) => d.serverValue == value,
    orElse: () => throw FormatException('알 수 없는 요일'),
  );
}

/// 시·분. Flutter 의 TimeOfDay 를 쓰지 않는다(domain 에 Flutter 금지). 종료는 `24:00`까지.
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  const TimeOfDayValue(this.hour, this.minute);

  final int hour;
  final int minute;

  static final _pattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$|^24:00$');

  static TimeOfDayValue parse(String value) {
    if (!_pattern.hasMatch(value)) throw FormatException('시각 형식 오류');
    final parts = value.split(':');
    return TimeOfDayValue(int.parse(parts[0]), int.parse(parts[1]));
  }

  int get minutesOfDay => hour * 60 + minute;

  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(TimeOfDayValue other) => minutesOfDay - other.minutesOfDay;

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayValue && other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => minutesOfDay;
}

/// 요일당 한 구간. 시작 포함·종료 미포함, start < end.
class AvailabilityWindow {
  const AvailabilityWindow({
    required this.day,
    required this.start,
    required this.end,
  });

  final DayOfWeek day;
  final TimeOfDayValue start;
  final TimeOfDayValue end;
}

class NotificationSettings {
  const NotificationSettings({
    required this.generalEnabled,
    required this.availability,
  });

  /// 일반 문의 알림. 긴급 알림은 항상 켜져 있고 설정 항목이 없다(FR-028).
  final bool generalEnabled;

  /// 비어 있으면 언제든 응답 가능(FR-029).
  final List<AvailabilityWindow> availability;
}

/// 알림 수신 기기 플랫폼(원본 명세 RegisterDeviceRequest.platform).
enum DevicePlatform {
  android('ANDROID'),
  ios('IOS');

  const DevicePlatform(this.serverValue);

  final String serverValue;
}
