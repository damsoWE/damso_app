import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/notice_text.dart';
import '../dial_launcher.dart';

/// 긴급 전달 안내 본문(F2-3 계열): F2-3 번호 없음(Figma 216-5319) · F2-3b 112·109(216-5360)
/// · F2-3c 109(216-5332) · F2-3d 112(216-5346). 문구는 모두 고정 문구(원칙 V).
/// 분류 결과를 기다리지 않고 받은 번호 목록 그대로 바로 그린다(FR-011).
class UrgentNoticeView extends ConsumerWidget {
  const UrgentNoticeView({super.key, required this.hotlines});

  final List<Hotline> hotlines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDial = ref.watch(canDialProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          NoticeText.of(Notice.urgentDelivered),
          style: AppTextStyles.display,
        ),
        if (hotlines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const Text('도움이 필요하시다면', style: AppTextStyles.subtitle),
          for (final h in hotlines) ...[
            const SizedBox(height: AppSpacing.sm),
            _HotlineCard(hotline: h, canDial: canDial),
          ],
        ],
      ],
    );
  }
}

class _HotlineCard extends ConsumerWidget {
  const _HotlineCard({required this.hotline, required this.canDial});

  final Hotline hotline;
  final bool canDial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = hotline.phoneNumber;
    return Card(
      color: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(NoticeText.hotline(hotline), style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.sm),
            // 전화 걸기 화면만 연다. 통화는 학부모가 직접 누른다(FR-010a).
            OutlinedButton(
              onPressed: canDial
                  ? () => ref.read(dialLauncherProvider).dial(number)
                  : null,
              child: Text('$number로 전화하기'),
            ),
          ],
        ),
      ),
    );
  }
}
