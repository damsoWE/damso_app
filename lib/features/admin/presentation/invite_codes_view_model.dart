import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository_provider.dart';
import '../domain/models.dart';

/// 학급별 발행 현황. 최근 발행 순.
class InviteCodesViewModel extends AsyncNotifier<List<InviteCodeStatus>> {
  InviteCodesViewModel(this.classroomId);

  final String classroomId;

  @override
  Future<List<InviteCodeStatus>> build() async {
    final list = await ref
        .watch(adminRepositoryProvider)
        .listInviteCodes(classroomId);
    return [...list]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  void refresh() => ref.invalidateSelf();
}

final inviteCodesViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<InviteCodesViewModel, List<InviteCodeStatus>, String>(
      InviteCodesViewModel.new,
    );
