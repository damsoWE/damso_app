import 'package:damso_app/features/inquiry/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// specs/002 data-model §1 "안내 화면 선택" 표.
void main() {
  group('번호 정리(Hotline.normalize)', () {
    test('서버 목록 그대로', () {
      expect(Hotline.normalize(['SUICIDE_PREVENTION_109']), [Hotline.suicidePrevention]);
      expect(Hotline.normalize(['CHILD_ABUSE_112']), [Hotline.childAbuse]);
      expect(Hotline.normalize([]), isEmpty);
      expect(
        Hotline.normalize(['CHILD_ABUSE_112', 'SUICIDE_PREVENTION_109']),
        [Hotline.childAbuse, Hotline.suicidePrevention],
      );
    });

    test('모르는 코드는 버리고, 다 버려졌으면 기본 안내(112·109)', () {
      expect(
        Hotline.normalize(['NEW_HOTLINE_119']),
        [Hotline.childAbuse, Hotline.suicidePrevention],
      );
      expect(
        Hotline.normalize(['NEW_HOTLINE_119', 'SUICIDE_PREVENTION_109']),
        [Hotline.suicidePrevention],
      );
    });
  });

  group('안내 화면 고르기(SubmitOutcome.from)', () {
    test('긴급이면 번호와 함께 긴급 안내', () {
      final outcome = SubmitOutcome.from(
        urgent: true,
        notices: const [Notice.urgentDelivered],
        hotlines: const [Hotline.suicidePrevention],
      );
      expect(outcome, isA<UrgentNotice>());
      expect((outcome as UrgentNotice).hotlines, [Hotline.suicidePrevention]);
    });

    test('긴급이면 지연 안내 코드가 있어도 긴급 안내', () {
      expect(
        SubmitOutcome.from(
          urgent: true,
          notices: const [Notice.urgentDelivered, Notice.deferred],
          hotlines: const [],
        ),
        isA<UrgentNotice>(),
      );
    });

    test('일반 + 응답 가능 시간 밖 → 지연 안내', () {
      expect(
        SubmitOutcome.from(
          urgent: false,
          notices: const [Notice.received, Notice.deferred],
          hotlines: const [],
        ),
        isA<DeferredNotice>(),
      );
    });

    test('일반 → 접수 안내', () {
      expect(
        SubmitOutcome.from(
          urgent: false,
          notices: const [Notice.received],
          hotlines: const [],
        ),
        isA<ReceivedNotice>(),
      );
    });
  });

  test('모르는 안내 코드는 버린다', () {
    expect(Notice.tryParse('SOMETHING_NEW'), isNull);
    expect(Notice.tryParse('DEFERRED_TO_AVAILABLE_HOURS'), Notice.deferred);
  });

  test('모르는 단계 값은 형식 오류', () {
    expect(() => InquiryStage.fromServer('UNKNOWN'), throwsFormatException);
    expect(InquiryStage.fromServer('REFINING'), InquiryStage.refined);
  });
}
