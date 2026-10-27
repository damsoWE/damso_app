import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/session/role.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/session/session_state.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_app.dart';

SessionState sessionOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(sessionControllerProvider);

/// US8: 서버 없이 mock 만으로 정상·오류·잠금·권한 없음·세션 만료를 재현한다(FR-012, SC-007).
void main() {
  testWidgets('세션 만료(갱신 거부) → 로그인 화면, 보호 화면으로 다시 가도 로그인 화면', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'expired@damso.test');

    expect(find.text('학부모 홈'), findsNothing);
    expect(find.widgetWithText(TextField, '이메일'), findsOneWidget); // C-1
    expect(sessionOf(tester), const SignedOut(sessionExpired: true));

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/parent');
    await tester.pumpAndSettle();
    expect(find.text('학부모 홈'), findsNothing);
    expect(find.widgetWithText(TextField, '이메일'), findsOneWidget);
  });

  testWidgets('접근 권한 만료 → 갱신 → 재시도 성공은 오류 없이 홈을 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'refresh@damso.test');

    expect(find.text('학부모 홈'), findsOneWidget);
    expect(find.text('김하나'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(sessionOf(tester), const SignedIn(Role.parent));
  });

  testWidgets('담당 학급이 없는 교사는 권한 없음 안내를 본다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'noclass@damso.test');
    await tester.tap(find.byTooltip('마이페이지'));
    await tester.pumpAndSettle();
    await tapText(tester, '학부모 연결 현황');
    expect(find.text('권한이 없습니다.'), findsOneWidget);
  });

  testWidgets('로그인 대기는 서버가 준 남은 시간을 보인다', (tester) async {
    await tester.pumpWidget(testApp());
    await login(tester, 'wait@damso.test', password: 'x');
    expect(find.text('30초 후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(isEnabled(tester, '로그인'), isFalse);

    await tester.pump(const Duration(seconds: 30));
    expect(isEnabled(tester, '로그인'), isTrue);
  });

  testWidgets('초대 코드 잠금은 남은 시간을 보이고 확인 버튼을 막는다', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tapText(tester, '초대코드로 가입하기');
    await enterField(tester, '초대 코드', 'ZZZZZZZZZZ');
    await enterField(tester, '이메일', 'new@damso.test');
    await tapText(tester, '코드 확인');

    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('10분 0초 후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(isEnabled(tester, '코드 확인'), isFalse);
  });

  group('F2 문의 mock 저장소 (quickstart "mock 데모 입력")', () {
    const hana = '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e51';
    const duri = '7c1e2a40-1b2c-4d3e-8f90-0a1b2c3d4e52';
    late MockInquiryStore store;
    var key = 0;

    InquirySubmitted send(String content, {String student = hana, String? k}) =>
        store.submit(
          parentAccount: 'parent',
          studentId: student,
          content: content,
          idempotencyKey: k ?? 'k${key++}',
        );

    setUp(() => store = MockInquiryStore());

    test('본문 단어별 결과 6종', () {
      expect(send('준비물 문의').outcome, isA<ReceivedNotice>());
      store = MockInquiryStore();
      expect(send('밤늦게 죄송해요').outcome, isA<DeferredNotice>());
      final cases = {
        '자해': [Hotline.suicidePrevention],
        '학대': [Hotline.childAbuse],
        '위험': <Hotline>[],
        '긴급': [Hotline.childAbuse, Hotline.suicidePrevention],
      };
      for (final MapEntry(key: word, value: hotlines) in cases.entries) {
        final outcome = send('$word 관련 문의').outcome;
        expect(outcome, isA<UrgentNotice>(), reason: word);
        expect((outcome as UrgentNotice).hotlines, hotlines, reason: word);
      }
    });

    test('60초 안 두 번째 일반 문의는 429, 긴급은 통과, 같은 키는 같은 결과', () {
      final first = send('첫 문의', k: 'same');
      expect(send('첫 문의', k: 'same').inquiryId, first.inquiryId);
      expect(
        () => send('두 번째 문의'),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 429)),
      );
      expect(send('자해가 걱정돼요').urgent, isTrue);
      expect(
        () => send('다른 내용', k: 'same'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'CONFLICT')),
      );
    });

    test('담임 없는 자녀(김두리)는 409', () {
      expect(
        () => send('문의', student: duri),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'NO_HOMEROOM_TEACHER'),
        ),
      );
    });

    test('학부모가 보낸 문의가 교사 목록에 보이고, 긴급은 맨 위', () {
      final sent = send('자해 걱정');
      final page = store.listForTeacher(page: 0, size: 20);
      expect(page.items.first.inquiryId, sent.inquiryId);
      expect(page.items.where((i) => i.title == '원문 확인 필요'), isNotEmpty);
      expect(page.totalElements, greaterThan(25));
      expect(page.hasMore, isTrue);
    });

    test('교사 두 번째 조회부터 "정리 중"이 정리 완료로, 학부모 단계는 접수 → 정제', () {
      const pending = 'a1000000-0000-4000-8000-000000000003';
      TeacherInquirySummary find(TeacherInquiryPage p) =>
          p.items.firstWhere((i) => i.inquiryId == pending);
      expect(find(store.listForTeacher(page: 0, size: 50)).title, '정리 중');
      final second = find(store.listForTeacher(page: 0, size: 50));
      expect(second.refinementStatus, RefinementStatus.refined);
      expect(
        store.listForParent('parent').firstWhere((s) => s.inquiryId == pending).stage,
        InquiryStage.refined,
      );
    });

    test('권한 확인(데모) 상세는 403', () {
      expect(
        () => store.detailForParent('parent', MockInquiryStore.forbiddenDemoId),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 403)),
      );
    });
  });

  testWidgets('refresh@ 계정: 문의 탭이 오류 없이 열린다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'refresh@damso.test');
    await tapTab(tester, '문의');
    expect(find.text('불러오지 못했습니다.'), findsNothing);
    expect(find.text('김하나 학생 문의'), findsWidgets);
  });
}
