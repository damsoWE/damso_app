import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inquiry_repository_impl.dart';
import '../domain/inquiry_repository.dart';

final inquiriesProvider = FutureProvider<List<Inquiry>>(
  (ref) => ref.watch(inquiryRepositoryProvider).list(),
);

/// 문의 목록 화면 자리표시. 실제 UI·상태는 F2 spec 에서 정의한다.
class InquiryListPage extends ConsumerWidget {
  const InquiryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiries = ref.watch(inquiriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('문의')),
      body: inquiries.when(
        data: (items) => ListView(
          children: [
            for (final i in items)
              ListTile(
                title: Text(i.summary),
                subtitle: Text(i.status.name),
                trailing: i.urgent ? const Icon(Icons.warning_amber) : null,
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        // 에러 상세(스택·내부 경로)는 화면에 노출하지 않는다(원칙 6).
        error: (_, _) => const Center(child: Text('불러오지 못했습니다.')),
      ),
    );
  }
}
