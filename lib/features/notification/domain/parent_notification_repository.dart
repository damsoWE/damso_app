/// 학부모 알림 설정(specs/007 data-model §7). 답변 도착 알림 하나뿐이다.
class ParentNotificationSettings {
  const ParentNotificationSettings({required this.answerNotifyEnabled});

  final bool answerNotifyEnabled;
}

/// 학부모 알림 설정 조회·저장(contracts/api-usage.md "ParentNotificationRepository").
abstract class ParentNotificationRepository {
  Future<ParentNotificationSettings> getSettings();

  /// 저장한 뒤 서버가 확정한 값을 돌려준다.
  Future<ParentNotificationSettings> saveSettings(bool answerNotifyEnabled);
}
