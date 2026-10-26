import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import '../theme/app_theme.dart';

/// 조회 화면 공통 상태(FR-041): 로딩 / 빈 목록 / 오류 + 다시 시도.
/// 오류는 [userMessageOf] 로만 표시한다(예외 내용 노출 금지).
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      data: (d) => isEmpty != null && empty != null && isEmpty!(d)
          ? empty!(context)
          : data(d),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetry(message: userMessageOf(e), onRetry: onRetry),
    );
  }
}

/// 오류 문구 + "다시 시도" 버튼.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
