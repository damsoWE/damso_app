import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/teacher_repository_provider.dart';
import '../domain/models.dart';
import '../domain/validators.dart';

class ProfileEditState {
  const ProfileEditState({
    required this.profile,
    this.isSaving = false,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  final TeacherProfile profile;
  final bool isSaving;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
}

/// F3-9 공개 프로필 편집. 사진은 없다(FR-029).
class ProfileEditViewModel extends AsyncNotifier<ProfileEditState> {
  @override
  Future<ProfileEditState> build() async => ProfileEditState(
    profile: await ref.watch(teacherRepositoryProvider).getProfile(),
  );

  void refresh() => ref.invalidateSelf();

  /// 성공하면 true.
  Future<bool> save({
    required String displayName,
    required String introduction,
  }) async {
    final current = state.value;
    if (current == null || current.isSaving) return false;
    final errors = <String, String>{
      'displayName': ?validateDisplayName(displayName),
      'introduction': ?validateIntroduction(introduction),
    };
    if (errors.isNotEmpty) {
      state = AsyncData(
        ProfileEditState(profile: current.profile, fieldErrors: errors),
      );
      return false;
    }
    state = AsyncData(ProfileEditState(profile: current.profile, isSaving: true));
    try {
      final saved = await ref
          .read(teacherRepositoryProvider)
          .updateProfile(
            TeacherProfile(
              displayName: displayName.trim(),
              introduction: introduction.trim(),
            ),
          );
      state = AsyncData(ProfileEditState(profile: saved));
      return true;
    } on AppException catch (e) {
      state = AsyncData(
        ProfileEditState(
          profile: current.profile,
          errorMessage: e.message,
          fieldErrors: e.fieldErrors,
        ),
      );
      return false;
    }
  }
}

final profileEditViewModelProvider =
    AsyncNotifierProvider.autoDispose<ProfileEditViewModel, ProfileEditState>(
      ProfileEditViewModel.new,
    );
