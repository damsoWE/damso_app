import 'dart:async';

import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/data/mock_parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/presentation/parent/compose_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Future<void> writeAndSend(WidgetTester tester, String content) async {
  await tapText(tester, '김하나 학생 문의 작성');
  await tester.enterText(find.byType(TextField), content);
  await tester.pump();
  await tapText(tester, '문의 보내기');
}

void main() {
  testWidgets('문의 작성 → 접수 안내 → 문의 탭 맨 위, 뒤로 가기로 작성 화면이 나오지 않는다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');

    await writeAndSend(tester, '내일 준비물이 궁금합니다.');
    expect(find.text('문의가 접수되었습니다.'), findsOneWidget);

    await tapText(tester, '보낸 문의 보기');
    expect(find.widgetWithText(AppBar, '문의'), findsOneWidget);
    expect(find.text('김하나 학생 문의'), findsWidgets);
    expect(find.text('문의 작성'), findsNothing); // 작성 화면이 아니다
  });

  testWidgets('담임 없는 자녀는 작성 화면 대신 안내', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');
    await tapText(tester, '김하나');
    await tapText(tester, '김두리');

    expect(find.text('담임 선생님이 연결된 뒤 문의할 수 있어요.'), findsOneWidget);
    await tester.tap(find.text('김두리 학생 문의 작성'));
    await tester.pumpAndSettle();
    expect(find.text('문의 내용'), findsNothing);
  });

  testWidgets('글을 쓰다가 뒤로 가면 확인을 받는다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');
    await tapText(tester, '김하나 학생 문의 작성');
    await tester.enterText(find.byType(TextField), '쓰는 중');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('작성한 내용이 사라집니다. 나갈까요?'), findsOneWidget);
    await tapText(tester, '계속 쓰기');
    expect(find.text('쓰는 중'), findsOneWidget);
  });

  testWidgets('밤늦게 → 응답 가능 시간 안내, 같은 단어라도 긴급이면 긴급 안내 (US5)', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');

    await writeAndSend(tester, '밤늦게 죄송합니다. 숙제 문의드려요.');
    expect(find.text('선생님 응답 가능 시간에 전달됩니다.'), findsOneWidget);
    await tapText(tester, '문의 목록으로');

    await tapTab(tester, '홈');
    await writeAndSend(tester, '밤늦게 긴급하게 연락드립니다.');
    expect(find.text('선생님께 바로 전달했어요.'), findsOneWidget);
  });

  testWidgets('60초 안에 일반 문의를 다시 보내면 남은 시간이 보이고 쓴 글이 남는다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');
    await writeAndSend(tester, '첫 번째 문의');
    await tapText(tester, '보낸 문의 보기');
    await tapTab(tester, '홈');

    await writeAndSend(tester, '두 번째 문의');
    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('후에 다시 시도할 수 있습니다.'), findsOneWidget);
    expect(find.text('두 번째 문의'), findsOneWidget);

    // 긴급은 제한 없이 접수된다(US2-6).
    await tester.enterText(find.byType(TextField), '아이가 자해를 한 것 같아요');
    await tester.pump();
    await tapText(tester, '문의 보내기');
    expect(find.text('선생님께 바로 전달했어요.'), findsOneWidget);
    expect(find.text('자살예방 상담전화 109'), findsOneWidget);
  });

  testWidgets('어디에도 수정·삭제·발송 예약 버튼이 없다 (SC-005, FR-008)', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');

    void expectNoEditDelete() {
      final labels = [
        ...tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
        ...tester.widgetList<Tooltip>(find.byType(Tooltip)).map((t) => t.message ?? ''),
      ];
      for (final word in ['수정', '삭제', '예약']) {
        expect(labels.where((l) => l.contains(word)), isEmpty, reason: word);
      }
    }

    expectNoEditDelete(); // 홈
    await tapText(tester, '김하나 학생 문의 작성');
    expectNoEditDelete(); // 작성
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapTab(tester, '문의');
    expectNoEditDelete(); // 목록
    await tester.tap(find.text('김하나 학생 문의').first);
    await tester.pumpAndSettle();
    expectNoEditDelete(); // 스레드(F4-1)
  });

  testWidgets('문의 탭 첫 화면에서 기기 뒤로 가기 → 앱을 닫지 않고 홈 탭으로', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'parent@damso.test');
    await tapTab(tester, '문의');

    await tester.binding.handlePopRoute(); // Android 뒤로 가기
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '학부모 홈'), findsOneWidget);

    // 홈 탭에서 자녀 선택 화면을 연 상태면 그 화면부터 닫는다.
    await tapText(tester, '김하나');
    expect(find.widgetWithText(AppBar, '자녀 선택'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '학부모 홈'), findsOneWidget);
  });

  testWidgets('보내는 중 뒤로 가기는 무시되고 긴급 안내가 보인다', (tester) async {
    useTallScreen(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(
      testApp(
        parentInquiry: (ref) => _GatedRepo(
          ref.watch(tokenStoreProvider),
          ref.watch(mockInquiryStoreProvider),
          gate,
        ),
      ),
    );
    await login(tester, 'parent@damso.test');
    await tapText(tester, '김하나 학생 문의 작성');
    await tester.enterText(find.byType(TextField), '아이가 자해를 한 것 같아요');
    await tester.pump();

    await tester.tap(find.text('문의 보내기'));
    await tester.pump(); // "보내는 중"
    // 보내는 중에는 화면을 닫을 수 없다(시스템 뒤로 가기 포함).
    final popScope = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(ComposePage),
        matching: find.byWidgetPredicate((w) => w is PopScope),
      ),
    );
    expect(popScope.canPop, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1)); // 응답 전 — 닫혔다면 전환이 끝나 사라진다
    expect(find.text('작성한 내용이 사라집니다. 나갈까요?'), findsNothing);
    expect(find.widgetWithText(AppBar, '문의 작성'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('선생님께 바로 전달했어요.'), findsOneWidget);
    expect(find.text('자살예방 상담전화 109'), findsOneWidget);
  });
}

/// 보내기 응답을 테스트가 풀어 줄 때까지 붙잡는 mock.
class _GatedRepo extends MockParentInquiryRepository {
  _GatedRepo(super.tokens, super.store, this.gate);

  final Completer<void> gate;

  @override
  Future<InquirySubmitted> submit({
    required String studentId,
    required String content,
    required String idempotencyKey,
  }) async {
    await gate.future;
    return super.submit(
      studentId: studentId,
      content: content,
      idempotencyKey: idempotencyKey,
    );
  }
}
