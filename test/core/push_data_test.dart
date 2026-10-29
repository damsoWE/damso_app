import 'package:damso_app/core/push/push_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '9d8c7b6a-5f4e-4d3c-8b2a-1f0e9d8c7b6a';

void main() {
  test('긴급 2종 + 올바른 문의 ID → 긴급 문의 상세', () {
    for (final kind in ['URGENT', 'URGENT_REMINDER']) {
      expect(
        PushData.fromMap({'kind': kind, 'inquiryId': _id}).route,
        '/teacher/inquiries/$_id/urgent',
        reason: kind,
      );
    }
  });

  test('일반·묶음 알림은 문의 목록', () {
    expect(
      PushData.fromMap({'kind': 'GENERAL', 'inquiryId': _id}).route,
      '/teacher/inquiries',
    );
    expect(
      PushData.fromMap({'kind': 'GENERAL_DIGEST', 'count': '3'}).route,
      '/teacher/inquiries',
    );
  });

  test('UUID 가 아니거나 없는 ID, 모르는 종류는 문의 목록', () {
    expect(
      PushData.fromMap({'kind': 'URGENT', 'inquiryId': '../admin'}).route,
      '/teacher/inquiries',
    );
    expect(PushData.fromMap({'kind': 'URGENT'}).route, '/teacher/inquiries');
    expect(PushData.fromMap({'kind': 'SOMETHING'}).kind, PushKind.unknown);
    expect(PushData.fromMap(const {}).route, '/teacher/inquiries');
  });

  test('답변 알림은 학부모 스레드로, 역할은 학부모', () {
    final data = PushData.fromMap({'kind': 'ANSWER', 'inquiryId': _id});
    expect(data.kind, PushKind.answer);
    expect(data.target, PushTarget.parent);
    expect(data.route, '/parent/inquiries/$_id/thread');
  });

  test('답변 알림의 문의 ID 가 UUID 가 아니거나 없으면 학부모 문의 목록', () {
    expect(
      PushData.fromMap({'kind': 'ANSWER', 'inquiryId': '../admin'}).route,
      '/parent/inquiries',
    );
    expect(PushData.fromMap({'kind': 'ANSWER'}).route, '/parent/inquiries');
  });

  test('교사용 알림 종류는 역할이 교사, 모르는 종류는 역할 없음', () {
    for (final kind in ['URGENT', 'URGENT_REMINDER', 'GENERAL', 'GENERAL_DIGEST']) {
      expect(PushData.fromMap({'kind': kind}).target, PushTarget.teacher, reason: kind);
    }
    expect(PushData.fromMap({'kind': 'SOMETHING'}).target, isNull);
  });
}
