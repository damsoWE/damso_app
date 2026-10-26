import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import 'links_view_model.dart';

/// F3-10 학부모 연결 현황 (Figma 216-5666). 학부모 이름·이메일은 보이지 않는다(FR-030).
/// "재발행 요청" 버튼은 API 가 없어 두지 않고 오프라인 요청 안내만 보인다.
class LinksPage extends ConsumerWidget {
  const LinksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('학부모 연결 현황')),
      body: AsyncView(
        value: ref.watch(linksViewModelProvider),
        onRetry: ref.read(linksViewModelProvider.notifier).refresh,
        data: (c) {
          final linked = c.students.where((s) => s.guardianLinked).length;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('${c.grade}학년 ${c.classNumber}반', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text('학부모 연결 $linked / ${c.students.length}명'),
              const SizedBox(height: AppSpacing.md),
              for (final s in c.students)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name),
                  trailing: Text(
                    s.guardianLinked ? '연결됨' : '미연결',
                    style: AppTextStyles.smallStrong.copyWith(
                      color: s.guardianLinked
                          ? AppColors.statusSuccess
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '코드 재발행이 필요하면 학교 관리자에게 요청해 주세요.',
                style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}
