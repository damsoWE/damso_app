import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/error/error_codes.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/admin/data/mock_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// specs/006 research R7 — mock 문의 현황.
void main() {
  MockAdminRepository repo(String account) =>
      MockAdminRepository(TokenStore()..accessToken = 'mock:$account');

  test('학급마다 학년·반 순, 3학년 2반만 건수가 있고 다른 학급은 0', () async {
    final admin = repo('admin');
    final classrooms = await admin.listClassrooms();
    final items = await admin.inquiryStatus();

    String label(String id) {
      final c = classrooms.firstWhere((c) => c.classroomId == id);
      return '${c.grade}-${c.classNumber}';
    }

    expect(items.map((i) => label(i.classroomId)), ['1-1', '3-2']);
    expect(items.first.total, 0);
    expect((items.last.waiting, items.last.confirmed, items.last.answered), (3, 2, 7));
  });

  test('학급을 추가하면 그 학급도 0으로 나온다', () async {
    final admin = repo('admin');
    final added = await admin.createClassroom(2, 5);
    final items = await admin.inquiryStatus();
    final row = items.firstWhere((i) => i.classroomId == added.classroomId);
    expect(row.total, 0);
    expect(items, hasLength(3));
  });

  test('슈퍼 관리자가 아니면 403, 서버 문구', () async {
    for (final account in ['teacher', 'parent']) {
      await expectLater(
        repo(account).inquiryStatus(),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', ErrorCodes.forbidden)
              .having((e) => e.statusCode, 'status', 403),
        ),
        reason: account,
      );
    }
  });

  test('refresh-admin 은 갱신 지연 뒤 성공한다', () async {
    final items = await repo('refresh-admin').inquiryStatus();
    expect(items, isNotEmpty);
  });
}
