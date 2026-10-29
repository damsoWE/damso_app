import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/admin/data/admin_repository_provider.dart';
import 'package:damso_app/features/admin/data/mock_admin_repository.dart';
import 'package:damso_app/features/admin/domain/models.dart';
import 'package:damso_app/features/admin/presentation/inquiry_status_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _c32 = 'c32';
const _c11 = 'c11';
const _new = 'c-new';

AdminClassroom _classroom(String id, int grade, int number, {bool homeroom = false}) =>
    AdminClassroom(
      classroomId: id,
      grade: grade,
      classNumber: number,
      homeroomAssigned: homeroom,
      studentCount: 0,
    );

ClassroomInquiryStatus _status(String id, int w, int c, int a) =>
    ClassroomInquiryStatus(classroomId: id, waiting: w, confirmed: c, answered: a);

/// 현황·학급 목록 응답을 테스트가 정하는 가짜 Repository. 나머지는 mock 그대로.
class _FakeAdmin extends MockAdminRepository {
  Completer<List<ClassroomInquiryStatus>> statusGate = Completer();
  Completer<List<AdminClassroom>> classroomGate = Completer();
  int statusCalls = 0;
  int classroomCalls = 0;

  @override
  Future<List<ClassroomInquiryStatus>> inquiryStatus() {
    statusCalls++;
    return statusGate.future;
  }

  @override
  Future<List<AdminClassroom>> listClassrooms() {
    classroomCalls++;
    return classroomGate.future;
  }
}

void main() {
  late _FakeAdmin repo;
  late ProviderContainer c;

  setUp(() {
    repo = _FakeAdmin();
    c = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );
    c.listen(inquiryStatusViewModelProvider, (_, _) {});
  });

  Future<InquiryStatusState> load({
    required List<ClassroomInquiryStatus> statuses,
    List<AdminClassroom>? classrooms,
    AppException? classroomError,
  }) {
    final future = c.read(inquiryStatusViewModelProvider.future);
    if (classroomError != null) {
      repo.classroomGate.completeError(classroomError);
    } else {
      repo.classroomGate.complete(classrooms ?? const []);
    }
    repo.statusGate.complete(statuses);
    return future;
  }

  test('현황과 학급 목록을 함께 요청한다(둘 다 끝나기 전에 둘 다 시작)', () async {
    c.read(inquiryStatusViewModelProvider);
    await pumpEventQueue();
    expect(repo.statusCalls, 1);
    expect(repo.classroomCalls, 1);
  });

  test('학급 이름·담임 연결을 합치고, 순서는 현황 순서, 요약은 학급별 합', () async {
    final s = await load(
      statuses: [_status(_c11, 0, 0, 0), _status(_c32, 3, 2, 7)],
      classrooms: [_classroom(_c32, 3, 2, homeroom: true), _classroom(_c11, 1, 1)],
    );
    expect(s.rows.map((r) => r.label), ['1학년 1반', '3학년 2반']);
    expect(s.rows.map((r) => r.homeroomAssigned), [false, true]);
    expect(
      (s.totals.total, s.totals.waiting, s.totals.confirmed, s.totals.answered),
      (12, 3, 2, 7),
    );
    expect(s.allZero, isFalse);
  });

  test('학급 목록에 없는 학급은 이름 null(“학급”)', () async {
    final s = await load(
      statuses: [_status(_c32, 1, 0, 0), _status(_new, 0, 0, 0)],
      classrooms: [_classroom(_c32, 3, 2)],
    );
    expect(s.rows.last.label, isNull);
    expect(s.rows.last.homeroomAssigned, isNull);
  });

  test('학급 목록만 실패하면 건수는 보이고 이름·담임은 모두 null', () async {
    final s = await load(
      statuses: [_status(_c32, 3, 2, 7)],
      classroomError: const AppException(message: '불러오지 못했습니다.'),
    );
    expect(s.rows.single.status.total, 12);
    expect(s.rows.single.label, isNull);
    expect(s.rows.single.homeroomAssigned, isNull);
  });

  test('현황이 실패하면 화면 전체 오류(서버 문구)', () async {
    repo.classroomGate.complete(const []);
    repo.statusGate.completeError(
      const AppException(message: '접근 권한이 없습니다.', statusCode: 403),
    );
    await expectLater(c.read(inquiryStatusViewModelProvider.future), throwsA(isA<AppException>()));
    final value = c.read(inquiryStatusViewModelProvider);
    expect(value.hasError, isTrue);
    expect((value.error! as AppException).message, '접근 권한이 없습니다.');
  });

  test('모두 0이면 allZero, 학급이 없으면 allZero 아님', () async {
    final zero = await load(
      statuses: [_status(_c11, 0, 0, 0), _status(_c32, 0, 0, 0)],
      classrooms: [_classroom(_c11, 1, 1), _classroom(_c32, 3, 2)],
    );
    expect(zero.allZero, isTrue);

    repo
      ..statusGate = Completer()
      ..classroomGate = Completer();
    c.invalidate(inquiryStatusViewModelProvider);
    final empty = await load(statuses: const []);
    expect(empty.rows, isEmpty);
    expect(empty.allZero, isFalse);
  });
}
