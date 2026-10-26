import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/inquiry/data/inquiry_repository_providers.dart';
import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:damso_app/features/inquiry/domain/teacher_inquiry_repository.dart';
import 'package:damso_app/features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TeacherInquirySummary _item(int n, {bool urgent = false, InquiryStage? stage}) =>
    TeacherInquirySummary(
      inquiryId: 'id-$n',
      studentId: 's',
      studentName: '학생$n',
      urgent: urgent,
      title: urgent ? '긴급 문의' : '문의 $n',
      stage: stage ?? (urgent ? InquiryStage.delivered : InquiryStage.received),
      refinementStatus: urgent ? null : RefinementStatus.pending,
      submittedAt: DateTime(2026, 10, 26),
    );

/// 전체 [total]건을 20건씩 나눠 주는 가짜 Repository.
class _PagedRepo implements TeacherInquiryRepository {
  _PagedRepo(this.total);

  int total;
  final pages = <int>[];
  bool failNext = false;
  Completer<void>? gate;

  @override
  Future<TeacherInquiryPage> list({int page = 0, int size = 20}) async {
    pages.add(page);
    await gate?.future;
    if (failNext) {
      failNext = false;
      throw const AppException(message: '불러오지 못했습니다.');
    }
    final start = page * size;
    final end = (start + size).clamp(0, total);
    return TeacherInquiryPage(
      items: [
        for (var n = start; n < end; n++)
          _item(n, urgent: n == 0, stage: n == 0 ? InquiryStage.delivered : null),
      ],
      page: page,
      size: size,
      totalElements: total,
    );
  }

  @override
  Future<TeacherInquiryDetail> detail(String inquiryId) => throw UnimplementedError();

  @override
  Future<String> content(String inquiryId) => throw UnimplementedError();
}

void main() {
  late _PagedRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _PagedRepo(45);
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [teacherInquiryRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(teacherInquiriesViewModelProvider, (_, _) {});
  });

  TeacherInquiriesViewModel vm() =>
      container.read(teacherInquiriesViewModelProvider.notifier);
  Future<TeacherInquiriesState> loaded() =>
      container.read(teacherInquiriesViewModelProvider.future);
  TeacherInquiriesState state() =>
      container.read(teacherInquiriesViewModelProvider).requireValue;

  test('페이지를 이어 붙이고 마지막 페이지에서 멈춘다', () async {
    expect((await loaded()).items, hasLength(20));
    await vm().loadMore();
    expect(state().items, hasLength(40));
    await vm().loadMore();
    expect(state().items, hasLength(45));
    expect(state().nextPage, isNull);
    await vm().loadMore();
    expect(repo.pages, [0, 1, 2]);
  });

  test('다음 페이지만 실패하면 기존 목록을 두고 다시 시도할 수 있다', () async {
    await loaded();
    repo.failNext = true;
    await vm().loadMore();
    expect(state().items, hasLength(20));
    expect(state().loadMoreError, '불러오지 못했습니다.');
    await vm().loadMore();
    expect(state().items, hasLength(40));
    expect(state().loadMoreError, isNull);
  });

  test('새로 고침 동안 이전 목록을 그대로 보인다', () async {
    await loaded();
    await vm().loadMore();
    repo.gate = Completer<void>();
    final refreshing = vm().refresh();
    expect(container.read(teacherInquiriesViewModelProvider).value?.items, hasLength(40));
    repo.gate!.complete();
    await refreshing;
    expect(state().items, hasLength(20)); // 0페이지부터 새로
  });

  test('홈 긴급 카드는 교사 확인 전 긴급만', () async {
    final s = await loaded();
    expect(s.unconfirmedUrgent.map((i) => i.inquiryId), ['id-0']);
  });
}
