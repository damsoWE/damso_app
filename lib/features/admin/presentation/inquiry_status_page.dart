import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/system_notice.dart';
import 'inquiry_status_view_model.dart';

/// ADM-4 문의 현황 (Figma 224-1387, F5 백엔드 결정 반영). 학급별 건수만 보인다 —
/// 문의 제목·본문·학생·학부모·교사 정보와 긴급 건수·기간은 없다(specs/006 FR-003, 원칙 VII).
/// 학급을 누르면 학급 상세(ADM-1)로 가고, 문의 목록·상세로 가는 이동은 없다(FR-005).
class InquiryStatusPage extends ConsumerWidget {
  const InquiryStatusPage({super.key});

  static const title = '문의 현황';
  static const metadataOnlyNotice = '관리자는 문의 건수와 처리 상태만 볼 수 있어요. 문의 내용과 답변은 볼 수 없어요.';
  static const allZeroNotice = '아직 접수된 문의가 없어요.';
  static const noClassrooms = '등록된 학급이 없습니다. 학급을 추가해 주세요.';
  static const unknownClass = '학급';

  static String rowCounts(int total, int waiting, int confirmed, int answered) =>
      '문의 $total · 답변 대기 $waiting · 교사 확인 $confirmed · 답변 완료 $answered';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(inquiryStatusViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: RefreshIndicator(
        onRefresh: vm.refresh,
        child: AsyncView(
          value: ref.watch(inquiryStatusViewModelProvider),
          onRetry: vm.refresh,
          data: (s) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SystemNotice(metadataOnlyNotice),
              if (s.rows.isEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text(noClassrooms, textAlign: TextAlign.center, style: AppTextStyles.body),
              ] else ...[
                if (s.allZero) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const SystemNotice(allZeroNotice, icon: Icons.info_outline),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('전체', style: AppTextStyles.subtitle),
                const SizedBox(height: AppSpacing.ms),
                _Summary(totals: s.totals),
                const SizedBox(height: AppSpacing.lg),
                const Text('학급별', style: AppTextStyles.subtitle),
                const SizedBox(height: AppSpacing.ms),
                for (final row in s.rows) ...[
                  _ClassroomCard(row: row),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 요약 4칸(전체 문의 · 답변 대기 · 교사 확인 · 답변 완료).
class _Summary extends StatelessWidget {
  const _Summary({required this.totals});

  final InquiryStatusTotals totals;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget a, Widget b) => Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.ms),
        Expanded(child: b),
      ],
    );
    return Column(
      children: [
        row(
          _SummaryCell('전체 문의', totals.total, AppColors.textPrimary),
          _SummaryCell('답변 대기', totals.waiting, AppColors.statusInfo),
        ),
        const SizedBox(height: AppSpacing.ms),
        row(
          _SummaryCell('교사 확인', totals.confirmed, AppColors.textPrimary),
          _SummaryCell('답변 완료', totals.answered, AppColors.statusSuccess),
        ),
      ],
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.bgSubtle,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.small.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text('$count', style: AppTextStyles.display.copyWith(color: color)),
      ],
    ),
  );
}

/// 학급 카드. 1줄 "3학년 2반 · 담임 연결됨", 2줄 건수. 누르면 학급 상세(ADM-1).
class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.row});

  final InquiryStatusRow row;

  @override
  Widget build(BuildContext context) {
    final s = row.status;
    final homeroom = switch (row.homeroomAssigned) {
      true => ' · 담임 연결됨',
      false => ' · 담임 미연결',
      null => '',
    };
    return Material(
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/admin/classrooms/${s.classroomId}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row.label ?? InquiryStatusPage.unknownClass}$homeroom',
                style: AppTextStyles.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                InquiryStatusPage.rowCounts(s.total, s.waiting, s.confirmed, s.answered),
                style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
