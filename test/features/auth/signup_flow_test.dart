import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('초대 코드 → 계정 정보 → 인증 → 이용 안내 → 학부모 홈', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tapText(tester, '초대코드로 가입하기');
    await enterField(tester, '초대 코드', 'parent cde2');
    expect(find.text('PARENTCDE2'), findsOneWidget); // 대문자·공백 제거
    await tapText(tester, '코드 확인');

    // F1-3: 연락처 입력란 없음 (FR-014, SC-005)
    expect(find.text('계정 만들기 · 학부모'), findsOneWidget);
    expect(find.textContaining('전화'), findsNothing);
    expect(find.textContaining('주소'), findsNothing);

    await enterField(tester, '이름', '김보호');
    await enterField(tester, '이메일', 'new@damso.test');
    await enterField(tester, '비밀번호', 'abcdefgh');
    expect(isEnabled(tester, '동의하고 계정 만들기'), isFalse); // 숫자 없음
    await enterField(tester, '비밀번호', 'abcd1234');
    expect(isEnabled(tester, '동의하고 계정 만들기'), isFalse); // 약관 미동의
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(isEnabled(tester, '동의하고 계정 만들기'), isTrue);
    await tapText(tester, '동의하고 계정 만들기');

    expect(find.text('이메일 인증'), findsOneWidget);
    expect(find.text('인증 코드는 10분 동안 유효합니다.'), findsOneWidget);
    await enterField(tester, '인증 코드', '123456');
    await tapText(tester, '인증하고 가입 완료');

    expect(find.text('담소 이용 안내'), findsOneWidget);
    await tapText(tester, '확인했어요');
    expect(find.text('학부모 홈'), findsOneWidget);
  });

  testWidgets('인증 중 초대 코드가 무효가 되면 코드 입력으로 돌아간다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tapText(tester, '초대코드로 가입하기');
    await enterField(tester, '초대 코드', 'TEACHERCD2');
    await tapText(tester, '코드 확인');
    expect(find.text('계정 만들기 · 교사'), findsOneWidget);
    await enterField(tester, '이름', '이담임');
    await enterField(tester, '이메일', 't@damso.test');
    await enterField(tester, '비밀번호', 'abcd1234');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tapText(tester, '동의하고 계정 만들기');

    await enterField(tester, '인증 코드', '999999');
    await tapText(tester, '인증하고 가입 완료');

    expect(find.text('초대코드 입력'), findsOneWidget);
    expect(find.text('코드를 확인해 주세요.'), findsOneWidget);
  });
}
