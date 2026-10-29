import 'dart:async';

import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/notice_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

/// 번역본·원문을 연 뒤 뒤에서 도는 목록 새로 고침(mock 300ms)까지 끝낸다.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> tapSettle(WidgetTester tester, String text) async {
  await tapText(tester, text);
  await settle(tester);
}

/// F3 화면 흐름(specs/003 quickstart 1~20, mock 데모 research R10).
void main() {
  /// 교사 문의 탭에서 제목·학생이 맞는 항목을 연다.
  Future<void> openInquiry(WidgetTester tester, String title, String student) async {
    final tiles = find.byType(ListTile);
    final list = tester.widgetList<ListTile>(tiles).toList();
    final index = list.indexWhere(
      (t) =>
          (t.title as Text).data == title &&
          ((t.subtitle as Text?)?.data ?? '').startsWith(student),
    );
    expect(index, isNot(-1), reason: '$title · $student 항목이 목록에 없다');
    await tester.ensureVisible(tiles.at(index));
    await tester.tap(tiles.at(index));
    await settle(tester);
  }

  /// 목록에서 제목·학생이 맞는 항목의 부제(학생 · 시각 · 단계).
  String subtitleOf(WidgetTester tester, String title, String student) => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => ((t.title as Text).data, (t.subtitle as Text?)?.data ?? ''))
      .firstWhere((t) => t.$1 == title && t.$2.startsWith(student))
      .$2;

  /// 학부모 정보·준비 중이 화면에 없다(FR-019, SC-006·008). "답변 작성" 버튼은
  /// F4(specs/004 FR-002)가 F3-2·F3-3·F3-6 하단에 더했으므로 여기서는 검사하지 않는다.
  void expectClean(WidgetTester tester) {
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
    expect(texts.where((t) => t.contains('@')), isEmpty);
    expect(texts.where((t) => t.contains('학부모')), isEmpty);
    expect(find.text('정리된 내용과 원문 보기는 준비 중입니다.'), findsNothing); // F2 자리 문구
  }

  Future<void> teacherInquiries(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await tapTab(tester, '문의');
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await settle(tester);
  }

  testWidgets('정리 완료(F3-2): 번역본·정서강도·라벨, 돌아오면 목록 단계 "교사 확인"', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');

    for (final t in [
      NoticeText.refinedBadge,
      NoticeText.translationLabel,
      NoticeText.factsLabel,
      NoticeText.requestsLabel,
      NoticeText.emotionTitle,
      '높음',
      '분노',
      '답답함',
      NoticeText.contentViewWillLog,
      '원문 보기',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('· 교사 확인'), findsOneWidget); // 머리 줄 단계(첫 열람 뒤)
    expectClean(tester);

    await back(tester);
    expect(subtitleOf(tester, '친구와 다툰 일 관련 문의', '이도윤'), endsWith('교사 확인'));
  });

  testWidgets('요청사항 없음·라벨 없음', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '체험학습 신청 관련 문의', '김하나');
    expect(find.text(NoticeText.noRequests), findsOneWidget);
    expect(find.text('낮음'), findsOneWidget);
    for (final label in ['불안', '불만', '분노', '걱정', '답답함', '슬픔']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('원문 확인 필요(F3-3) → 다시 정리하기 실패 → 버튼 없음', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '원문 확인 필요', '이도윤');

    expect(find.text(NoticeText.refinementFailed), findsOneWidget);
    expect(find.text('원문 보기'), findsOneWidget);
    // 단계가 접수면 머리 줄에 단계를 붙이지 않는다("… 접수 · 접수" 반복 방지).
    expect(find.textContaining('접수 · 접수'), findsNothing);
    expect(find.textContaining(RegExp(r'^이도윤 · .* 접수$')), findsOneWidget);
    expect(find.text(NoticeText.factsLabel), findsNothing); // 정리 결과 없음(원칙 IV)
    expectClean(tester);

    await tapSettle(tester, NoticeText.retryButton);
    for (final t in [
      NoticeText.retryingBadge,
      NoticeText.retryingHeading,
      NoticeText.retryRemainingTitle,
      NoticeText.recheckButton,
      '원문 보기',
      '문의 목록으로',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expectClean(tester);

    await tapSettle(tester, NoticeText.recheckButton);
    expect(find.text(NoticeText.retryButton), findsNothing);
    expect(find.text(NoticeText.retryLimitReached), findsOneWidget);
  });

  testWidgets('다시 정리하기 성공 → 다시 확인하면 번역본', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '원문 확인 필요', '박서준');
    await tapSettle(tester, NoticeText.retryButton);
    await tapSettle(tester, NoticeText.recheckButton);
    expect(find.text(NoticeText.factsLabel), findsOneWidget);
  });

  testWidgets('원문 열람(F3-6) → 문의 상세로, 원문 확인 필요 첫 열람은 "교사 확인"', (tester) async {
    await teacherInquiries(tester);
    // 박서준의 원문 확인 필요 두 건 중 재시도를 이미 쓴 문의(…0007)는 다시 정리하기 버튼이 없다.
    final candidates = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where(
          (t) =>
              (t.title as Text).data == '원문 확인 필요' &&
              ((t.subtitle as Text?)?.data ?? '').startsWith('박서준'),
        )
        .length;
    expect(candidates, 2);
    final tiles = find.byType(ListTile);
    final all = tester.widgetList<ListTile>(tiles).toList();
    final index = all.lastIndexWhere(
      (t) =>
          (t.title as Text).data == '원문 확인 필요' &&
          ((t.subtitle as Text?)?.data ?? '').startsWith('박서준'),
    );
    await tester.ensureVisible(tiles.at(index));
    await tester.tap(tiles.at(index));
    await settle(tester);
    expect(find.text(NoticeText.retryLimitReached), findsOneWidget);

    await tapSettle(tester, '원문 보기');
    for (final t in [
      '작성한 원문',
      '(mock) 데모 문의 원문입니다.',
      NoticeText.contentViewedLogged,
      '문의 상세로',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expectClean(tester);

    await tapSettle(tester, '문의 상세로');
    expect(find.text(NoticeText.needsOriginalHeading), findsOneWidget);
    expect(find.textContaining('· 교사 확인'), findsOneWidget);

    await back(tester);
    final subtitles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => ((t.title as Text).data, (t.subtitle as Text?)?.data ?? ''))
        .where((t) => t.$1 == '원문 확인 필요' && t.$2.startsWith('박서준'))
        .map((t) => t.$2)
        .toList();
    expect(subtitles.last, endsWith('교사 확인'));
  });

  testWidgets('정리 중: 다른 문의를 열고 와도 그대로, 다시 확인하면 번역본', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await back(tester); // 목록 새로 고침이 일어난 상태(analyze G1)

    // 3시간 전 정리 중 문의(…000a). F2 데모(…0003)는 이미 정리 완료일 수 있어 마지막 항목을 연다.
    final tiles = find.byType(ListTile);
    final all = tester.widgetList<ListTile>(tiles).toList();
    final index = all.lastIndexWhere(
      (t) =>
          (t.title as Text).data == '정리 중' &&
          ((t.subtitle as Text?)?.data ?? '').startsWith('김하나'),
    );
    await tester.ensureVisible(tiles.at(index));
    await tester.tap(tiles.at(index));
    await settle(tester);

    for (final t in [
      NoticeText.refiningHeading,
      NoticeText.refiningGuide,
      '원문 보기',
      NoticeText.recheckButton,
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text(NoticeText.retryRemainingTitle), findsNothing);
    expect(find.text(NoticeText.factsLabel), findsNothing);
    expectClean(tester);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(NoticeText.refiningHeading), findsOneWidget); // 저절로 바뀌지 않는다

    await tapSettle(tester, NoticeText.recheckButton);
    expect(find.text(NoticeText.factsLabel), findsOneWidget);
  });

  testWidgets('정리 중: 당겨서 새로 고침으로도 번역본', (tester) async {
    await teacherInquiries(tester);
    final tiles = find.byType(ListTile);
    final all = tester.widgetList<ListTile>(tiles).toList();
    final index = all.lastIndexWhere(
      (t) =>
          (t.title as Text).data == '정리 중' &&
          ((t.subtitle as Text?)?.data ?? '').startsWith('김하나'),
    );
    await tester.ensureVisible(tiles.at(index));
    await tester.tap(tiles.at(index));
    await settle(tester);
    expect(find.text(NoticeText.refiningHeading), findsOneWidget);

    // 테스트 환경의 끌기 제스처로는 새로 고침이 시작되지 않아, 상세 화면의 RefreshIndicator 를
    // 직접 띄워 onRefresh(recheck) 연결을 확인한다.
    final indicator = find.ancestor(
      of: find.text(NoticeText.refiningHeading),
      matching: find.byType(RefreshIndicator),
    );
    unawaited(tester.state<RefreshIndicatorState>(indicator).show());
    await settle(tester);
    expect(find.text(NoticeText.factsLabel), findsOneWidget);
  });

  testWidgets('긴급 문의를 일반 상세 주소로 열면 긴급 상세로 한 번만 옮기고 원문도 한 번(코드 리뷰 6)', (tester) async {
    await teacherInquiries(tester);
    const urgentId = 'a1000000-0000-4000-8000-000000000001';
    final context = tester.element(find.byType(Scaffold).first);
    final store = ProviderScope.containerOf(context).read(mockInquiryStoreProvider);
    unawaited(GoRouter.of(context).push('/teacher/inquiries/$urgentId/general'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1)); // 다시 그려도 이동이 반복되지 않는지
    await settle(tester);

    expect(find.text(NoticeText.urgentDetailGuide), findsOneWidget);
    expect(store.contentViewsOf(urgentId), 1);

    await back(tester); // replace 였으므로 바로 문의 목록
    expect(find.text(NoticeText.urgentDetailGuide), findsNothing);
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('원문 화면 머리 줄은 상세 화면의 요약으로 그린다(코드 리뷰 4·5)', (tester) async {
    await teacherInquiries(tester);
    await openInquiry(tester, '친구와 다툰 일 관련 문의', '이도윤');
    await tapSettle(tester, '원문 보기');
    expect(find.text('친구와 다툰 일 관련 문의'), findsOneWidget);
    expect(find.textContaining('이도윤 · '), findsOneWidget);
    expect(find.text('작성한 원문'), findsOneWidget);
  });
}
