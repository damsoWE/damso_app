import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/data/mock_teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/notice_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// 원문 호출 횟수를 세는 mock.
class _CountingTeacherRepo extends MockTeacherInquiryRepository {
  _CountingTeacherRepo(super.tokens, super.store);

  final contentCalls = <String>[];
  int failDetail = 0;

  /// 남은 횟수만큼 원문 열람을 기록 실패(500)로 거부한다(api-v0.10).
  int failContent = 0;

  @override
  Future<String> content(String inquiryId) async {
    contentCalls.add(inquiryId);
    if (failContent > 0) {
      failContent--;
      throw const AppException(
        message: '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        code: 'INTERNAL_ERROR',
        statusCode: 500,
      );
    }
    return super.content(inquiryId);
  }

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) async {
    if (failDetail > 0) {
      failDetail--;
      throw const AppException(message: '불러오지 못했습니다.');
    }
    return super.detail(inquiryId);
  }
}

/// 화면의 모든 글자에 '@'(이메일)가 없는지.
void expectNoEmail(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
  expect(texts.where((t) => t.contains('@')), isEmpty);
}

void main() {
  late _CountingTeacherRepo repo;

  Widget app() => testApp(
    teacherInquiry: (ref) => repo = _CountingTeacherRepo(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    ),
  );

  testWidgets('홈 긴급 카드 → 원문 1회 열람, 돌아오면 긴급 카드가 사라진다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');

    expect(find.text('긴급 문의 1건'), findsOneWidget);
    expectNoEmail(tester);
    await tapText(tester, '긴급 문의 1건');

    expect(find.text('(mock) 데모 문의 원문입니다.'), findsOneWidget);
    expect(find.text('원문을 열람한 기록이 남습니다.'), findsOneWidget);
    // 첫 열람으로 바뀐 "교사 확인"까지 채워진 단계 3개(접수·전달됨·교사 확인)
    expect(find.byIcon(Icons.circle), findsNWidgets(3));
    expectNoEmail(tester);
    expect(repo.contentCalls, hasLength(1));

    // 다시 그려도(탭 이동 없이 프레임 갱신) 원문은 다시 부르지 않는다.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.contentCalls, hasLength(1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('긴급 문의 1건'), findsNothing);
  });

  testWidgets('문의 탭: 긴급이 맨 위, 원문 확인 필요 문의는 F3-3 이고 원문을 부르지 않는다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');
    await tapTab(tester, '문의');

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles.take(2), ['긴급 문의', '긴급 문의']);
    expectNoEmail(tester);

    await tapText(tester, '원문 확인 필요');
    expect(find.text(NoticeText.refinementFailed), findsOneWidget);
    expect(repo.contentCalls, isEmpty); // 원문은 "원문 보기"를 누를 때만(specs/003 research R6)
  });

  testWidgets('원문 열람 기록이 실패하면 화면 전체가 서버 문구 + 다시 시도, 다시 시도하면 긴급 상세(F5 US3-2·3)', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');
    repo.failContent = 1;
    await tapText(tester, '긴급 문의 1건');

    expect(find.text('요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('(mock) 데모 문의 원문입니다.'), findsNothing);
    expect(find.text('원문을 열람한 기록이 남습니다.'), findsNothing);
    expectNoEmail(tester);

    await tapText(tester, '다시 시도');
    expect(find.text('(mock) 데모 문의 원문입니다.'), findsOneWidget);
    expect(repo.contentCalls, hasLength(2));
  });

  testWidgets('상세가 먼저 실패하면 원문을 열지 않고, 다시 시도하면 원문 열람은 한 번, 홈 긴급 카드는 사라진다', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(app());
    await login(tester, 'teacher@damso.test');
    repo.failDetail = 1;
    await tapText(tester, '긴급 문의 1건');
    expect(find.text('불러오지 못했습니다.'), findsOneWidget);
    expect(repo.contentCalls, isEmpty); // 긴급인지 확인하기 전에는 원문을 열지 않는다

    await tapText(tester, '다시 시도');
    expect(find.text('(mock) 데모 문의 원문입니다.'), findsOneWidget);
    expect(repo.contentCalls, hasLength(1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('긴급 문의 1건'), findsNothing);
  });
}
