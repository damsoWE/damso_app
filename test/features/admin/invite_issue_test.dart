import 'package:damso_app/features/admin/data/admin_repository_provider.dart';
import 'package:damso_app/features/admin/data/mock_admin_repository.dart';
import 'package:damso_app/features/admin/domain/models.dart';
import 'package:damso_app/features/admin/presentation/classroom_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

class _CountingAdmin extends MockAdminRepository {
  int parentIssues = 0;
  int inviteCodeLoads = 0;

  @override
  Future<IssuedInviteCode> issueParentInvite(String studentId) {
    parentIssues++;
    return super.issueParentInvite(studentId);
  }

  @override
  Future<List<InviteCodeStatus>> listInviteCodes(String classroomId) {
    inviteCodeLoads++;
    return super.listInviteCodes(classroomId);
  }
}

final _codePattern = RegExp(r'^[A-HJKMNP-Z2-9]{10}$');

/// 화면에 보이는 10자리 초대 코드 문자열들.
Iterable<String> _visibleCodes(WidgetTester tester) => [
  ...tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
  ...tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((t) => t.data ?? ''),
].where(_codePattern.hasMatch);

void main() {
  testWidgets('교사 코드는 발행 완료 화면에서만 보이고, 떠나면 어디에도 없다 (SC-006)', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'admin@damso.test');
    expect(find.text('관리자 홈'), findsOneWidget);

    await tapText(tester, '1학년 1반');
    await tapText(tester, '교사 초대코드 발행');

    expect(find.text('교사 코드 발행 완료'), findsOneWidget);
    expect(find.textContaining('만료:'), findsOneWidget);
    expect(find.text('이 화면을 떠나면 코드를 다시 볼 수 없습니다.'), findsOneWidget);
    final code = _visibleCodes(tester).single;

    await tapText(tester, '목록으로');
    expect(find.text('1학년 1반'), findsOneWidget);
    expect(find.text(code), findsNothing);
    expect(find.text('교사 코드 재발행'), findsOneWidget); // 미사용 코드 생김

    await tapText(tester, '발행 현황');
    expect(find.text('교사 코드'), findsOneWidget);
    expect(find.text('미사용'), findsOneWidget);
    expect(find.text(code), findsNothing);
    expect(_visibleCodes(tester), isEmpty);
  });

  testWidgets('미사용 코드가 있는 학생의 재발행은 확인(ADM-6)을 거친다', (tester) async {
    useTallScreen(tester);
    final admin = _CountingAdmin();
    await tester.pumpWidget(testApp(admin: admin));
    await login(tester, 'admin@damso.test');
    await tapText(tester, '3학년 2반');

    expect(find.text('교사 초대코드 발행'), findsNothing); // 담임 있음
    await tapText(tester, '재발행'); // 박서준

    expect(find.text('이전 코드는 즉시 무효가 됩니다.'), findsOneWidget);
    expect(admin.parentIssues, 0);
    await tapText(tester, '취소');
    expect(admin.parentIssues, 0);

    await tapText(tester, '재발행');
    await tapText(tester, '새 코드 발행');
    expect(admin.parentIssues, 1);
    expect(find.text('학부모 코드 발행 완료'), findsOneWidget);
    expect(find.text('박서준 학생의 학부모 초대 코드'), findsOneWidget);
  });

  test('담임 있는 학급의 교사 코드 발행은 서버 안내를 돌려준다', () async {
    final admin = MockAdminRepository();
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [adminRepositoryProvider.overrideWithValue(admin)],
    );
    final c32 = (await admin.listClassrooms()).firstWhere(
      (c) => c.grade == 3 && c.classNumber == 2,
    );
    final provider = classroomDetailViewModelProvider(c32.classroomId);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);

    final result = await container
        .read(provider.notifier)
        .issue(TeacherInviteTarget(c32.classroomId));
    expect(result, isA<IssueFailed>());
    expect((result as IssueFailed).message, '이미 담임이 연결된 학급입니다.');
  });

  test('발행이 실패해도(409) 학급 상세를 다시 불러온다', () async {
    final admin = _CountingAdmin();
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [adminRepositoryProvider.overrideWithValue(admin)],
    );
    final c32 = (await admin.listClassrooms()).firstWhere((c) => c.grade == 3);
    final provider = classroomDetailViewModelProvider(c32.classroomId);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    final loads = admin.inviteCodeLoads;

    // 3학년 2반은 담임이 있어 CLASSROOM_HAS_TEACHER(409).
    final result = await container
        .read(provider.notifier)
        .issue(TeacherInviteTarget(c32.classroomId));
    expect(result, isA<IssueFailed>());
    await container.read(provider.future);
    expect(admin.inviteCodeLoads, loads + 1);
  });
}
