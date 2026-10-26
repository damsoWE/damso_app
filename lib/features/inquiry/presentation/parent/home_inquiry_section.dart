import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import 'inquiry_card.dart';
import 'parent_inquiries_view_model.dart';

/// 학부모 홈(F2-1/F2-1b)의 문의 영역: 고른 자녀의 최근 문의 3건(FR-017).
class HomeInquirySection extends ConsumerWidget {
  const HomeInquirySection({super.key, required this.studentId});

  final String studentId;

  static const _max = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(parentInquiriesViewModelProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('진행 중인 문의', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.sm),
        switch (value) {
          AsyncData(:final value) => () {
            final mine = value.where((s) => s.studentId == studentId).take(_max);
            if (mine.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('아직 보낸 문의가 없습니다.', style: AppTextStyles.body),
              );
            }
            return Column(
              children: [
                for (final s in mine) ...[
                  InquiryCard(
                    summary: s,
                    expandable: false,
                    onTap: () => context.go('/parent/inquiries'),
                    onUrgentTap: () =>
                        context.push('/parent/inquiries/${s.inquiryId}/urgent'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }(),
          AsyncError(:final error) => Text(
            userMessageOf(error),
            style: AppTextStyles.small.copyWith(color: AppColors.statusUrgentText),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}
