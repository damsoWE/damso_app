import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/admin/data/mock_admin_repository.dart';
import 'package:damso_app/features/admin/domain/models.dart';
import 'package:damso_app/features/admin/presentation/inquiry_status_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 현황·학급 목록 응답을 바꿀 수 있는 mock. 정하지 않으면 mock 그대로.
class _Admin extends MockAdminRepository {
  List<ClassroomInquiryStatus> Function(List<AdminClassroom>)? statuses;
  AppException? statusError;
  AppException? classroomError;

  @override
  Future<List<AdminClassroom>> listClassrooms() async {
    final error = classroomError;
    if (error != null) throw error;
    return super.listClassrooms();
  }

  @override
  Future<List<ClassroomInquiryStatus>> inquiryStatus() async {
    final error = statusError;
    if (error != null) throw error;
    final make = statuses;
    if (make == null) return super.inquiryStatus();
    return make(await super.listClassrooms());
  }
}

/// specs/006 US1 — ADM-4 문의 현황 화면.
void main() {
  Future<void> openStatus(WidgetTester tester, {_Admin? admin}) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp(admin: admin));
    await login(tester, 'admin@damso.test');
    await tapTab(tester, '문의');
    await tester.pumpAndSettle();
  }

  List<String> allTexts(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();

  testWidgets('하단 탭 셋, 상단 안내, 요약 4칸, 학급별 건수', (tester) async {
    await openStatus(tester);

    for (final tab in ['홈', '문의', '마이페이지']) {
      expect(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
        findsOneWidget,
      );
    }
    expect(find.text(InquiryStatusPage.title), findsOneWidget);
    expect(find.text(InquiryStatusPage.metadataOnlyNotice), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    for (final label in ['전체 문의', '답변 대기', '교사 확인', '답변 완료']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('12'), findsOneWidget);
    expect(find.text('학급별'), findsOneWidget);
    expect(find.text('3학년 2반 · 담임 연결됨'), findsOneWidget);
    expect(find.text('문의 12 · 답변 대기 3 · 교사 확인 2 · 답변 완료 7'), findsOneWidget);
    // 문의가 없는 학급도 0으로 보인다(US1-3).
    expect(find.text('1학년 1반 · 담임 미연결'), findsOneWidget);
    expect(find.text('문의 0 · 답변 대기 0 · 교사 확인 0 · 답변 완료 0'), findsOneWidget);
    expect(find.text(InquiryStatusPage.allZeroNotice), findsNothing);
  });

  testWidgets('화면 어디에도 이메일·학생 이름·긴급·기간이 없다(FR-003)', (tester) async {
    await openStatus(tester);

    final texts = allTexts(tester).join('\n');
    for (final word in ['@', '김하나', '박서준', '이도윤', '긴급', '이번 주', '이○○']) {
      expect(texts.contains(word), isFalse, reason: word);
    }
  });

  testWidgets('학급 카드를 누르면 학급 상세(ADM-1)', (tester) async {
    await openStatus(tester);
    await tapText(tester, '3학년 2반 · 담임 연결됨');
    expect(find.text('3학년 2반'), findsOneWidget); // 학급 상세 제목
    expect(find.text('박서준'), findsOneWidget); // 학급 상세의 학생 명단
  });

  testWidgets('모두 0이면 안내를 함께, 학급이 없으면 학급 추가 안내', (tester) async {
    final admin = _Admin()
      ..statuses = (list) => [
        for (final c in list)
          ClassroomInquiryStatus(
            classroomId: c.classroomId,
            waiting: 0,
            confirmed: 0,
            answered: 0,
          ),
      ];
    await openStatus(tester, admin: admin);
    expect(find.text(InquiryStatusPage.allZeroNotice), findsOneWidget);
    expect(find.text('문의 0 · 답변 대기 0 · 교사 확인 0 · 답변 완료 0'), findsNWidgets(2));

    // 다른 탭에 갔다가 돌아오면 다시 불러온다(FR-007).
    admin.statuses = (_) => const [];
    await tapTab(tester, '홈');
    await tapTab(tester, '문의');
    await tester.pumpAndSettle();
    expect(find.text(InquiryStatusPage.noClassrooms), findsOneWidget);
  });

  testWidgets('학급 목록에 없는 학급은 "학급", 세 자리 건수도 그대로', (tester) async {
    final admin = _Admin()
      ..statuses = (_) => const [
        ClassroomInquiryStatus(
          classroomId: '0e1f2a3b-4c5d-4e6f-8a7b-9c0d1e2f3a4b',
          waiting: 120,
          confirmed: 340,
          answered: 1005,
        ),
      ];
    await openStatus(tester, admin: admin);
    expect(find.text(InquiryStatusPage.unknownClass), findsOneWidget);
    expect(find.text('문의 1465 · 답변 대기 120 · 교사 확인 340 · 답변 완료 1005'), findsOneWidget);
    expect(find.text('1465'), findsOneWidget);
  });

  testWidgets('학급 목록만 실패하면 건수는 보이고 이름은 "학급", 담임 표시 없음', (tester) async {
    final admin = _Admin()..classroomError = const AppException(message: '불러오지 못했습니다.');
    await openStatus(tester, admin: admin);
    expect(find.text(InquiryStatusPage.unknownClass), findsNWidgets(2));
    expect(find.textContaining('담임'), findsNothing);
    expect(find.text('문의 12 · 답변 대기 3 · 교사 확인 2 · 답변 완료 7'), findsOneWidget);
  });

  testWidgets('현황 오류는 서버 문구와 다시 시도만, 다시 시도하면 다시 불러온다', (tester) async {
    final admin = _Admin()
      ..statusError = const AppException(message: '접근 권한이 없습니다.', statusCode: 403);
    await openStatus(tester, admin: admin);
    expect(find.text('접근 권한이 없습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('학급별'), findsNothing);

    admin.statusError = null;
    await tapText(tester, '다시 시도');
    expect(find.text('학급별'), findsOneWidget);
  });
}
