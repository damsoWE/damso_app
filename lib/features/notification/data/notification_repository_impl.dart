import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/models.dart';
import '../domain/notification_repository.dart';

/// 실서버 구현. 경로는 원본 명세 0.5.0(specs/002 contracts/api-usage.md).
/// FCM 토큰은 로그·저장하지 않는다(FR-031c).
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._dio);

  final Dio _dio;

  static const _settingsPath = '/api/v1/teacher/notification-settings';

  @override
  Future<NotificationSettings> getSettings() {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(_settingsPath);
      return _settings(res.data!);
    });
  }

  @override
  Future<NotificationSettings> saveSettings(NotificationSettings settings) {
    return mapDioErrors(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        _settingsPath,
        data: {
          'generalEnabled': settings.generalEnabled,
          'availability': [
            for (final w in settings.availability)
              {
                'dayOfWeek': w.day.serverValue,
                'start': w.start.format(),
                'end': w.end.format(),
              },
          ],
        },
      );
      return _settings(res.data!);
    });
  }

  @override
  Future<void> registerDevice({
    required String token,
    required DevicePlatform platform,
  }) {
    return mapDioErrors(() async {
      await _dio.put<void>(
        '/api/v1/me/devices',
        data: {'token': token, 'platform': platform.serverValue},
      );
    });
  }

  @override
  Future<void> unregisterCurrentDevice() {
    return mapDioErrors(() async {
      await _dio.delete<void>('/api/v1/me/devices/current');
    });
  }

  static NotificationSettings _settings(Map<String, dynamic> j) =>
      NotificationSettings(
        generalEnabled: j['generalEnabled'] as bool,
        availability: [
          for (final w in (j['availability'] as List).cast<Map<String, dynamic>>())
            AvailabilityWindow(
              day: DayOfWeek.fromServer(w['dayOfWeek'] as String),
              start: TimeOfDayValue.parse(w['start'] as String),
              end: TimeOfDayValue.parse(w['end'] as String),
            ),
        ],
      );
}
