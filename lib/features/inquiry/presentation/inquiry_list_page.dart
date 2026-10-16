import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import 'inquiry_list_view_model.dart';

/// 문의 목록 화면 자리표시. 실제 UI·상태는 F2 spec 에서 정의한다.
class InquiryListPage extends ConsumerWidget {
  const InquiryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiries = ref.watch(inquiryListViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('문의')),
      body: inquiries.when(
        data: (items) => RefreshIndicator(
          onRefresh: ref.read(inquiryListViewModelProvider.notifier).refresh,
          child: ListView(
            children: [
              for (final i in items)
                ListTile(
                  title: Text(i.summary),
                  subtitle: Text(i.status.name),
                  trailing: i.urgent ? const Icon(Icons.warning_amber) : null,
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        // 서버 message 만 보여 준다. 예외 객체·스택은 노출하지 않는다(원칙 6).
        error: (e, _) =>
            Center(child: Text(e is AppException ? e.message : '불러오지 못했습니다.')),
      ),
    );
  }
}
