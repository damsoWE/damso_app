import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/data/mock_parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 상세 호출 횟수를 세는 mock.
class _CountingRepo extends MockParentInquiryRepository {
  _CountingRepo(super.tokens, super.store);

  int detailCalls = 0;
  int listCalls = 0;

  @override
  Future<ParentInquiryDetail> detail(String inquiryId) {
    detailCalls++;
    return super.detail(inquiryId);
  }

  @override
  Future<List<ParentInquirySummary>> list() {
    listCalls++;
    return super.list();
  }
}

void main() {
  late _CountingRepo repo;

  Widget app() => testApp(
    parentInquiry: (ref) => repo = _CountingRepo(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    ),
  );

  testWidgets('카드를 펼치면 단계가 보이고, 접었다 펼쳐도 상세는 한 번만 부른다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'parent@damso.test');
    await tapTab(tester, '문의');

    final firstExpand = find.byTooltip('펼치기').first;
    await tester.tap(firstExpand);
    await tester.pumpAndSettle();
    expect(find.text('접수'), findsWidgets);
    expect(find.text('교사 확인'), findsWidgets);
    expect(repo.detailCalls, 1);

    await tester.tap(find.byTooltip('접기').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('펼치기').first);
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 1);
  });

  testWidgets('F3: 학부모 카드에는 단계만, 번역본·정서강도·정리 상태 문구는 없다(specs/003 US5)', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'parent@damso.test');
    await tapTab(tester, '문의');

    // 최근 순: …0003(2시간 전) · …000a(3시간 전, 정리 중) · …0009(4시간 전, 정리 완료)
    await tester.tap(find.byTooltip('펼치기').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('펼치기').at(1)); // 펼친 카드는 '접기'가 되어 다음 카드가 at(1)
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 2);

    expect(find.text('정제'), findsWidgets);
    for (final hidden in ['번역본', '정서강도', '자동 정리', '원문 확인 필요', '정리 중']) {
      expect(find.textContaining(hidden), findsNothing, reason: hidden);
    }
  });

  testWidgets('권한 확인(데모) 카드를 펼치면 서버 안내', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'parent@damso.test');
    await tapTab(tester, '문의');

    final card = find.ancestor(
      of: find.text('권한 확인(데모) 학생 문의'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('접근 권한이 없습니다.'), findsOneWidget);
  });

  testWidgets('홈은 고른 자녀의 문의만, 다른 탭에서 돌아오면 목록을 다시 불러온다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'parent@damso.test');

    expect(find.text('진행 중인 문의'), findsOneWidget);
    expect(find.text('김하나 학생 문의'), findsWidgets);
    await tapText(tester, '김하나');
    await tapText(tester, '김두리');
    expect(find.text('아직 보낸 문의가 없습니다.'), findsOneWidget);

    final before = repo.listCalls;
    await tapTab(tester, '마이페이지');
    await tapTab(tester, '문의');
    expect(repo.listCalls, greaterThan(before));
  });

  test('mock 저장소: 교사 두 번째 조회 뒤 학부모 쪽 단계가 접수 → 정제', () {
    final store = MockInquiryStore();
    const pendingId = 'a1000000-0000-4000-8000-000000000003';
    expect(
      store.listForParent('parent').firstWhere((s) => s.inquiryId == pendingId).stage,
      InquiryStage.received,
    );
    store.listForTeacher(page: 0, size: 20);
    store.listForTeacher(page: 0, size: 20);
    expect(
      store.listForParent('parent').firstWhere((s) => s.inquiryId == pendingId).stage,
      InquiryStage.refined,
    );
  });

  testWidgets('다른 탭에 다녀오면 펼친 카드의 상세를 다시 불러온다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'parent@damso.test');
    await tapTab(tester, '문의');
    await tester.tap(find.byTooltip('펼치기').first);
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 1);

    await tapTab(tester, '홈');
    await tapTab(tester, '문의');
    await tester.tap(find.byTooltip('펼치기').first);
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 2);
  });
}
