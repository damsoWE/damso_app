import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import 'admin_home_view_model.dart';
import 'format.dart';

/// ADM-1a 관리자 홈 (Figma 216-5699) · ADM-1b 학급별 등록 현황 (216-5716).
/// 문의 관련 정보는 보이지 않는다(FR-037).
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classrooms = ref.watch(adminHomeViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 홈'),
        actions: [
          IconButton(
            tooltip: '마이페이지',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/admin/me'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/classrooms/new'),
        icon: const Icon(Icons.add),
        label: const Text('학급 추가'),
      ),
      body: AsyncView(
        value: classrooms,
        onRetry: ref.read(adminHomeViewModelProvider.notifier).refresh,
        isEmpty: (list) => list.isEmpty,
        empty: (_) => const Center(child: Text('등록된 학급이 없습니다. 학급을 추가해 주세요.')),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = list[i];
            return ListTile(
              title: Text(
                classroomLabel(c.grade, c.classNumber),
                style: AppTextStyles.subtitle,
              ),
              subtitle: Text(
                '${c.homeroomAssigned ? '담임 연결됨' : '담임 미연결'} · 학생 ${c.studentCount}명',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/classrooms/${c.classroomId}'),
            );
          },
        ),
      ),
    );
  }
}
