import '../util/uuid.dart';

/// 기기 알림 권한 상태. "정하지 않음"일 때만 요청한다(spec FR-031a).
enum PushPermission { notDetermined, granted, denied }

/// 알림 종류(서버 FcmPayload `data.kind`).
enum PushKind { urgent, urgentReminder, general, generalDigest, unknown }

/// 알림의 화면 이동 데이터. 서버는 종류와 문의 UUID 만 보낸다(이름·본문 없음).
/// 이 값은 이동에만 쓰고 저장·로그하지 않는다(FR-031c).
class PushData {
  const PushData({required this.kind, this.inquiryId});

  factory PushData.fromMap(Map<String, dynamic> data) {
    final id = data['inquiryId'];
    return PushData(
      kind: switch (data['kind']) {
        'URGENT' => PushKind.urgent,
        'URGENT_REMINDER' => PushKind.urgentReminder,
        'GENERAL' => PushKind.general,
        'GENERAL_DIGEST' => PushKind.generalDigest,
        _ => PushKind.unknown,
      },
      inquiryId: id is String && isUuid(id) ? id : null,
    );
  }

  final PushKind kind;
  final String? inquiryId;

  bool get isUrgent => kind == PushKind.urgent || kind == PushKind.urgentReminder;

  /// 이동할 교사 화면(specs/002 data-model §5).
  String get route {
    final id = inquiryId;
    if (isUrgent && id != null) return '/teacher/inquiries/$id/urgent';
    return '/teacher/inquiries';
  }
}

/// 앱이 열려 있을 때 받은 알림. 제목·본문은 서버 고정 문구다.
class PushMessage {
  const PushMessage({required this.title, required this.body, required this.data});

  final String title;
  final String body;
  final PushData data;
}

/// 기기 알림 감싸기. 앱 코드는 이 인터페이스만 알고, FCM 구현과 빈 구현은
/// push_messaging_provider.dart 한 곳에서 고른다(research R9).
abstract class PushMessaging {
  /// false 면 알림 기능이 없는 실행(mock·테스트·Firebase 설정 없음).
  bool get isAvailable;

  /// `ANDROID`·`IOS`(기기 등록 요청 값).
  String get platform;

  Future<PushPermission> permissionStatus();

  Future<PushPermission> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Stream<PushMessage> get onForegroundMessage;

  /// 백그라운드 상태에서 알림을 눌러 앱이 열렸을 때.
  Stream<PushData> get onMessageOpened;

  /// 꺼진 상태에서 알림을 눌러 앱이 시작됐을 때(한 번).
  Future<PushData?> initialMessage();
}
