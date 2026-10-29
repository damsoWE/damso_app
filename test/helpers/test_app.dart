import 'package:damso_app/app/app.dart';
import 'package:damso_app/core/session/session_controller.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/me/data/me_repository_provider.dart';
import 'package:damso_app/features/notification/data/mock_notification_repository.dart';
import 'package:damso_app/features/notification/data/notification_repository_provider.dart';
import 'package:damso_app/features/notification/domain/notification_repository.dart';
import 'package:damso_app/features/me/data/mock_me_repository.dart';
import 'package:damso_app/features/parent/data/mock_parent_repository.dart';
import 'package:damso_app/features/parent/data/parent_repository_provider.dart';
import 'package:damso_app/features/teacher/data/mock_teacher_repository.dart';
import 'package:damso_app/features/teacher/data/teacher_repository_provider.dart';
import 'package:damso_app/features/admin/data/admin_repository_provider.dart';
import 'package:damso_app/features/admin/data/mock_admin_repository.dart';
import 'package:damso_app/features/admin/domain/admin_repository.dart';
import 'package:damso_app/features/auth/data/auth_repository_provider.dart';
import 'package:damso_app/features/auth/data/mock_auth_repository.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/data/mock_parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/data/mock_teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/parent_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/teacher_inquiry_repository.dart';
import 'package:damso_app/features/reply/data/answer_repository_provider.dart';
import 'package:damso_app/features/reply/data/mock_answer_repository.dart';
import 'package:damso_app/features/reply/domain/answer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트는 USE_MOCK 없이 실행되므로 모든 Repository 를 mock 으로 바꾼다.
/// mock 들은 앱과 같은 tokenStoreProvider 를 공유한다(데모 계정 구분).
/// 인자로 넘긴 Repository 가 있으면 그것을, 없으면 기본 mock 을 쓴다.
List<Override> mockRepositoryOverrides({
  AdminRepository? admin,
  ParentInquiryRepository Function(Ref ref)? parentInquiry,
  TeacherInquiryRepository Function(Ref ref)? teacherInquiry,
  AnswerRepository Function(Ref ref)? answer,
  NotificationRepository? notification,
}) => [
  notificationRepositoryProvider.overrideWith(
    (_) => notification ?? MockNotificationRepository(),
  ),
  authRepositoryProvider.overrideWith(
    (ref) => MockAuthRepository(ref.watch(tokenStoreProvider)),
  ),
  // 문의 mock 은 학부모·교사가 저장소를 공유한다. 테스트마다 새 저장소(ProviderScope 마다 새로 만든다).
  mockInquiryStoreProvider.overrideWith((_) => MockInquiryStore()),
  parentInquiryRepositoryProvider.overrideWith(
    (ref) => parentInquiry?.call(ref) ?? MockParentInquiryRepository(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    ),
  ),
  teacherInquiryRepositoryProvider.overrideWith(
    (ref) => teacherInquiry?.call(ref) ?? MockTeacherInquiryRepository(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    ),
  ),
  // 답변 mock 도 교사 문의 mock 과 같은 저장소를 쓴다(보낸 답변이 스레드에 보인다).
  answerRepositoryProvider.overrideWith(
    (ref) => answer?.call(ref) ?? MockAnswerRepository(
      ref.watch(tokenStoreProvider),
      ref.watch(mockInquiryStoreProvider),
    ),
  ),
  adminRepositoryProvider.overrideWith(
    (ref) => admin ?? MockAdminRepository(ref.watch(tokenStoreProvider)),
  ),
  parentRepositoryProvider.overrideWith(
    (ref) => MockParentRepository(
      ref.watch(tokenStoreProvider),
      () => ref.read(sessionControllerProvider.notifier).expire(),
    ),
  ),
  teacherRepositoryProvider.overrideWith(
    (ref) => MockTeacherRepository(ref.watch(tokenStoreProvider)),
  ),
  meRepositoryProvider.overrideWith(
    (ref) => MockMeRepository(ref.watch(tokenStoreProvider)),
  ),
];

/// 앱 전체를 mock 으로 띄운다. 자동 재시도는 끈다(main.dart 와 같은 설정).
Widget testApp({
  AdminRepository? admin,
  ParentInquiryRepository Function(Ref ref)? parentInquiry,
  TeacherInquiryRepository Function(Ref ref)? teacherInquiry,
  AnswerRepository Function(Ref ref)? answer,
  NotificationRepository? notification,
  List<Override> extraOverrides = const [],
}) {
  FlutterSecureStorage.setMockInitialValues({});
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      ...mockRepositoryOverrides(
        admin: admin,
        parentInquiry: parentInquiry,
        teacherInquiry: teacherInquiry,
        answer: answer,
        notification: notification,
      ),
      ...extraOverrides,
    ],
    child: const DamsoApp(),
  );
}

/// 긴 입력 화면이 한 화면에 들어오도록 세로로 긴 화면을 쓴다.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterField(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

/// 라벨이 [label] 인 FilledButton 이 눌릴 수 있는지.
bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label)).onPressed !=
    null;

/// 하단 탭 이동(홈 · 문의 · 마이페이지).
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// 앱 시작 → 시작 화면 → 로그인.
Future<void> login(WidgetTester tester, String email, {String password = 'damso1234'}) async {
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, '로그인'));
  await tester.pumpAndSettle();
  await enterField(tester, '이메일', email);
  await enterField(tester, '비밀번호', password);
  await tester.tap(find.widgetWithText(FilledButton, '로그인'));
  await tester.pumpAndSettle();
}
