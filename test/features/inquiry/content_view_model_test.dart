import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/core/storage/token_store.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/data/mock_inquiry_store.dart';
import 'package:damso_app/features/inquiry/data/mock_teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/presentation/teacher/content_view_model.dart';
import 'package:damso_app/features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 원문·상세·목록 호출을 세고, 원문 실패를 끼워 넣는 mock.
class _CountingRepo extends MockTeacherInquiryRepository {
  _CountingRepo() : super(TokenStore(), MockInquiryStore());

  int contentCalls = 0;
  int detailCalls = 0;
  int listCalls = 0;
  int failContent = 0;

  @override
  Future<String> content(String inquiryId) async {
    contentCalls++;
    if (failContent > 0) {
      failContent--;
      throw const AppException(message: '원문을 불러오지 못했습니다.');
    }
    return super.content(inquiryId);
  }

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) {
    detailCalls++;
    return super.detail(inquiryId);
  }

  @override
  Future<TeacherInquiryPage> list({int page = 0, int size = 20}) {
    listCalls++;
    return super.list(page: page, size: size);
  }
}

void main() {
  const id = 'a1000000-0000-4000-8000-000000000007'; // 원문 확인 필요(재시도 사용함)
  final provider = contentViewModelProvider(id);
  late _CountingRepo repo;
  late ProviderContainer c;

  setUp(() {
    repo = _CountingRepo();
    c = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [teacherInquiryRepositoryProvider.overrideWithValue(repo)],
    );
  });

  test('화면 하나에서 원문은 한 번만, 다시 읽어도 그대로', () async {
    c.listen(provider, (_, _) {});
    expect(await c.read(provider.future), '(mock) 데모 문의 원문입니다.');
    c.read(provider);
    await c.read(provider.future);
    expect(repo.contentCalls, 1);
  });

  test('상세는 부르지 않는다(머리 줄은 상세 화면이 넘긴 요약, 코드 리뷰 반영)', () async {
    c.listen(provider, (_, _) {});
    await c.read(provider.future);
    expect(repo.detailCalls, 0);
  });

  test('원문 실패 → 원문 없이 오류, 다시 시도하면 다시 부른다', () async {
    repo.failContent = 1;
    c.listen(provider, (_, _) {});
    await expectLater(c.read(provider.future), throwsA(isA<AppException>()));
    expect(c.read(provider).hasValue, isFalse);
    c.invalidate(provider);
    await c.read(provider.future);
    expect(repo.contentCalls, 2);
  });

  test('열람 기록 실패(500)면 원문 없이 서버 문구, 다시 시도하면 원문(F5 US3-1·3, mock 데모)', () async {
    const demo = MockInquiryStore.contentLogFailDemoId;
    final demoProvider = contentViewModelProvider(demo);
    c.listen(demoProvider, (_, _) {});
    await expectLater(
      c.read(demoProvider.future),
      throwsA(
        isA<AppException>()
            .having((e) => e.statusCode, 'status', 500)
            .having((e) => e.message, 'message', '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.'),
      ),
    );
    expect(c.read(demoProvider).hasValue, isFalse); // 원문은 일부도 없다

    c.invalidate(demoProvider); // 다시 시도
    expect(await c.read(demoProvider.future), '(mock) 데모 문의 원문입니다.');
  });

  test('원문을 받은 뒤 목록을 새로 고친다', () async {
    c.listen(teacherInquiriesViewModelProvider, (_, _) {});
    await c.read(teacherInquiriesViewModelProvider.future);
    final before = repo.listCalls;
    c.listen(provider, (_, _) {});
    await c.read(provider.future);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(repo.listCalls, greaterThan(before));
  });

  test('화면을 새로 열면(Provider 새로 생성) 원문을 다시 부른다', () async {
    final sub = c.listen(provider, (_, _) {});
    await c.read(provider.future);
    sub.close();
    await Future<void>.delayed(Duration.zero); // autoDispose
    c.listen(provider, (_, _) {});
    await c.read(provider.future);
    expect(repo.contentCalls, 2);
  });
}
