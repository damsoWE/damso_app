import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/parent_notification_repository.dart';

/// 실서버 구현. 경로는 api-v0.11 `/api/v1/parent/notification-settings`.
class ParentNotificationRepositoryImpl implements ParentNotificationRepository {
  ParentNotificationRepositoryImpl(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/parent/notification-settings';

  @override
  Future<ParentNotificationSettings> getSettings() {
    return mapDioErrors(() async {
      final res = await _dio.get<Map<String, dynamic>>(_path);
      return _settings(res.data!);
    });
  }

  @override
  Future<ParentNotificationSettings> saveSettings(bool answerNotifyEnabled) {
    return mapDioErrors(() async {
      final res = await _dio.put<Map<String, dynamic>>(
        _path,
        data: {'answerNotifyEnabled': answerNotifyEnabled},
      );
      return _settings(res.data!);
    });
  }

  static ParentNotificationSettings _settings(Map<String, dynamic> j) =>
      ParentNotificationSettings(answerNotifyEnabled: j['answerNotifyEnabled'] as bool);
}
