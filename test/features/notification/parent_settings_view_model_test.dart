import 'dart:async';

import 'package:damso_app/core/error/app_exception.dart';
import 'package:damso_app/features/notification/data/parent_notification_repository_provider.dart';
import 'package:damso_app/features/notification/domain/parent_notification_repository.dart';
import 'package:damso_app/features/notification/presentation/parent_settings_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 저장 호출을 기록하고 [save]로 결과를 정하는 가짜 Repository.
class _FakeRepo implements ParentNotificationRepository {
  bool server = true;
  final saves = <bool>[];
  Completer<void>? gate;
  Future<ParentNotificationSettings> Function(bool enabled)? save;

  @override
  Future<ParentNotificationSettings> getSettings() async =>
      ParentNotificationSettings(answerNotifyEnabled: server);

  @override
  Future<ParentNotificationSettings> saveSettings(bool answerNotifyEnabled) async {
    saves.add(answerNotifyEnabled);
    await gate?.future;
    return save != null
        ? save!(answerNotifyEnabled)
        : ParentNotificationSettings(answerNotifyEnabled: answerNotifyEnabled);
  }
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;
  final provider = parentSettingsViewModelProvider;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [parentNotificationRepositoryProvider.overrideWithValue(repo)],
    );
    container.listen(provider, (_, _) {});
  });

  ParentSettingsViewModel vm() => container.read(provider.notifier);
  ParentSettingsState state() => container.read(provider).requireValue;

  test('로드한 서버 값을 보인다', () async {
    repo.server = false;
    container.invalidate(provider);
    await container.read(provider.future);
    expect(state().answerNotifyEnabled, isFalse);
    expect(state().saving, isFalse);
  });

  test('토글 → saving true → 서버 응답 값으로 확정', () async {
    await container.read(provider.future);
    repo.gate = Completer<void>();
    final pending = vm().setAnswerNotify(false);
    expect(state().saving, isTrue);
    expect(state().answerNotifyEnabled, isTrue); // 서버 확정 전에는 원래 값

    repo.gate!.complete();
    await pending;
    expect(state().saving, isFalse);
    expect(state().answerNotifyEnabled, isFalse);
  });

  test('실패 → 원래 값과 서버 메시지', () async {
    await container.read(provider.future);
    repo.save = (_) async => throw const AppException(message: '저장하지 못했습니다.');
    await vm().setAnswerNotify(false);
    expect(state().answerNotifyEnabled, isTrue);
    expect(state().errorMessage, '저장하지 못했습니다.');
    expect(state().saving, isFalse);
  });

  test('saving 중 토글은 무시한다', () async {
    await container.read(provider.future);
    repo.gate = Completer<void>();
    final first = vm().setAnswerNotify(false);
    await vm().setAnswerNotify(true);
    repo.gate!.complete();
    await first;
    expect(repo.saves, [false]);
  });
}
