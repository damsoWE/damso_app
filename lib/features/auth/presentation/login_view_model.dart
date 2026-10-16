import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_provider.dart';

/// 로그인 ViewModel. 상태는 진행 중(loading) / 성공(data) / 실패(error).
class LoginViewModel extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// 성공하면 true. 실패 원인은 state 의 error 로 화면에 전달된다.
  Future<bool> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    return !state.hasError;
  }
}

final loginViewModelProvider = AsyncNotifierProvider<LoginViewModel, void>(
  LoginViewModel.new,
);
