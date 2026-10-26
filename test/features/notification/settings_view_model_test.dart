import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/notification/data/mock_notification_repository.dart';
import 'package:damso_app/features/notification/data/notification_repository_provider.dart';
import 'package:damso_app/features/notification/domain/models.dart';
import 'package:damso_app/features/notification/presentation/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

class _SpyRepo extends MockNotificationRepository {
  int saveCalls = 0;
  NotificationSettings? lastSaved;
  AppException? failWith;

  @override
  Future<NotificationSettings> saveSettings(NotificationSettings settings) {
    saveCalls++;
    lastSaved = settings;
    final e = failWith;
    if (e != null) throw e;
    return super.saveSettings(settings);
  }
}

void main() {
  late _SpyRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _SpyRepo();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(settingsViewModelProvider, (_, _) {});
  });

  SettingsViewModel vm() => container.read(settingsViewModelProvider.notifier);
  Future<SettingsForm> loaded() => container.read(settingsViewModelProvider.future);
  SettingsForm form() => container.read(settingsViewModelProvider).requireValue;

  test('설정 전: 요일 없음(언제든 응답 가능), 일반 알림 켜짐', () async {
    final f = await loaded();
    expect(f.alwaysAvailable, isTrue);
    expect(f.generalEnabled, isTrue);
  });

  test('월 09:00~17:00 저장 → 다시 불러오면 같은 값', () async {
    await loaded();
    vm().toggleDay(DayOfWeek.monday);
    vm().setEnd(const TimeOfDayValue(17, 0));
    expect(await vm().save(), isTrue);
    expect(form().saved, isTrue);

    container.invalidate(settingsViewModelProvider);
    final again = await loaded();
    expect(again.days, {DayOfWeek.monday});
    expect(again.start, const TimeOfDayValue(9, 0));
    expect(again.end, const TimeOfDayValue(17, 0));
  });

  test('시작 ≥ 종료면 안내만 보이고 저장 요청을 보내지 않는다', () async {
    await loaded();
    vm().toggleDay(DayOfWeek.monday);
    vm().setStart(const TimeOfDayValue(18, 0));
    vm().setEnd(const TimeOfDayValue(18, 0));
    expect(await vm().save(), isFalse);
    expect(form().timeError, SettingsViewModel.startAfterEnd);
    expect(repo.saveCalls, 0);
  });

  test('종료 24:00 허용, 일반 알림 끄기 저장', () async {
    await loaded();
    vm().toggleDay(DayOfWeek.sunday);
    vm().setEnd(TimeOfDayValue.parse('24:00'));
    vm().setGeneralEnabled(false);
    expect(await vm().save(), isTrue);
    expect(repo.lastSaved!.generalEnabled, isFalse);
    expect(repo.lastSaved!.availability.single.end.format(), '24:00');
  });

  test('서버 400 fieldErrors 는 시각 안내로', () async {
    await loaded();
    vm().toggleDay(DayOfWeek.monday);
    repo.failWith = const AppException(
      message: '입력값을 확인해 주세요.',
      fieldErrors: {'availability[0]': '시작 시각은 종료 시각보다 빨라야 합니다.'},
    );
    expect(await vm().save(), isFalse);
    expect(form().timeError, '시작 시각은 종료 시각보다 빨라야 합니다.');
  });

  testWidgets('화면: 긴급 알림 끄는 항목이 없고 안내만 있다, 학부모는 들어갈 수 없다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(testApp());
    await login(tester, 'teacher@damso.test');
    await tapTab(tester, '마이페이지');
    await tapText(tester, '응답 가능 시간 · 알림');

    expect(find.text('일반 문의 알림'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget); // 일반 알림 하나뿐
    expect(find.textContaining('긴급 문의 알림은 시간과 관계없이 항상'), findsOneWidget);
  });

  test('요일마다 다른 시각은 시각을 바꾸지 않으면 그대로 저장된다', () async {
    await repo.saveSettings(
      NotificationSettings(
        generalEnabled: true,
        availability: [
          AvailabilityWindow(
            day: DayOfWeek.monday,
            start: TimeOfDayValue.parse('09:00'),
            end: TimeOfDayValue.parse('18:00'),
          ),
          AvailabilityWindow(
            day: DayOfWeek.wednesday,
            start: TimeOfDayValue.parse('13:00'),
            end: TimeOfDayValue.parse('20:00'),
          ),
        ],
      ),
    );
    container.invalidate(settingsViewModelProvider);
    expect((await loaded()).mixedTimes, isTrue);

    vm().setGeneralEnabled(false);
    expect(await vm().save(), isTrue);
    final wed = repo.lastSaved!.availability.firstWhere(
      (w) => w.day == DayOfWeek.wednesday,
    );
    expect(wed.start.format(), '13:00');
    expect(wed.end.format(), '20:00');

    // 시각을 바꾸면 고른 요일 모두 같은 시각
    vm().setStart(TimeOfDayValue.parse('08:00'));
    expect(await vm().save(), isTrue);
    expect(
      repo.lastSaved!.availability.map((w) => w.start.format()).toSet(),
      {'08:00'},
    );
  });
}
