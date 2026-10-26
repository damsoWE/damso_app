import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/validation/validators.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../data/me_repository_provider.dart';
import '../domain/me.dart';

class MeState {
  const MeState({
    required this.me,
    this.isSubmitting = false,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  final Me me;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
}

/// 마이페이지 공통: 내 정보·이름 수정·로그아웃·탈퇴.
class MeViewModel extends AsyncNotifier<MeState> {
  @override
  Future<MeState> build() async =>
      MeState(me: await ref.watch(meRepositoryProvider).getMe());

  void refresh() => ref.invalidateSelf();

  void _set({
    bool isSubmitting = false,
    String? errorMessage,
    Map<String, String> fieldErrors = const {},
    Me? me,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      MeState(
        me: me ?? current.me,
        isSubmitting: isSubmitting,
        errorMessage: errorMessage,
        fieldErrors: fieldErrors,
      ),
    );
  }

  /// C-9 이름 수정(1~20자). 성공하면 true.
  Future<bool> updateName(String name) async {
    if (state.value == null || state.value!.isSubmitting) return false;
    final clientError = validateName(name);
    if (clientError != null) {
      _set(fieldErrors: {'name': clientError});
      return false;
    }
    _set(isSubmitting: true);
    try {
      final me = await ref.read(meRepositoryProvider).updateName(name.trim());
      _set(me: me);
      return true;
    } on AppException catch (e) {
      _set(errorMessage: e.message, fieldErrors: e.fieldErrors);
      return false;
    }
  }

  /// 이 기기만 로그아웃. 서버 호출이 실패해도 기기 세션은 지운다(FR-022).
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on AppException {
      // 서버 실패는 무시한다 — 기기 세션은 아래에서 지운다.
    } finally {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }

  /// C-8 회원 탈퇴. 성공하면 세션을 지우고 라우터가 시작 화면으로 보낸다.
  Future<void> withdraw(String password) async {
    if (state.value == null || state.value!.isSubmitting) return;
    final clientError = validateCurrentPassword(password);
    if (clientError != null) {
      _set(fieldErrors: {'password': clientError});
      return;
    }
    _set(isSubmitting: true);
    try {
      await ref.read(meRepositoryProvider).withdraw(password);
      await ref.read(sessionControllerProvider.notifier).signOut();
    } on AppException catch (e) {
      _set(errorMessage: e.message);
    }
  }
}

final meViewModelProvider =
    AsyncNotifierProvider.autoDispose<MeViewModel, MeState>(MeViewModel.new);
