import '../../../core/error/app_exception.dart';
import '../../../core/error/error_codes.dart';
import '../domain/models.dart';
import '../domain/notification_repository.dart';

/// mock 구현. 설정은 메모리에만 있고(설정 전: 일반 알림 켜짐, 응답 가능 시간 없음),
/// 시작 ≥ 종료면 서버처럼 400 INVALID_INPUT 을 준다. 기기 등록·해제 호출은 기록만 한다.
class MockNotificationRepository implements NotificationRepository {
  static const _delay = Duration(milliseconds: 300);

  NotificationSettings _settings = const NotificationSettings(
    generalEnabled: true,
    availability: [],
  );

  /// 테스트용: 등록된 토큰(해제되면 null).
  String? registeredToken;
  int registerCalls = 0;
  int unregisterCalls = 0;

  @override
  Future<NotificationSettings> getSettings() async {
    await Future<void>.delayed(_delay);
    return _settings;
  }

  @override
  Future<NotificationSettings> saveSettings(NotificationSettings settings) async {
    await Future<void>.delayed(_delay);
    final errors = <String, String>{};
    final days = <DayOfWeek>{};
    for (final (i, w) in settings.availability.indexed) {
      if (w.start.compareTo(w.end) >= 0) {
        errors['availability[$i]'] = '시작 시각은 종료 시각보다 빨라야 합니다.';
      }
      if (!days.add(w.day)) errors['availability[$i]'] = '같은 요일이 두 번 있습니다.';
    }
    if (errors.isNotEmpty) {
      throw AppException(
        message: '입력값을 확인해 주세요.',
        code: ErrorCodes.invalidInput,
        statusCode: 400,
        fieldErrors: errors,
      );
    }
    return _settings = settings;
  }

  @override
  Future<void> registerDevice({
    required String token,
    required DevicePlatform platform,
  }) async {
    registerCalls++;
    registeredToken = token;
  }

  @override
  Future<void> unregisterCurrentDevice() async {
    unregisterCalls++;
    registeredToken = null;
  }
}
