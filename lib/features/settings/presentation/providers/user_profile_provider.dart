import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class UserProfileState {
  final String? userName;
  final String? avatarPath;

  const UserProfileState({
    this.userName,
    this.avatarPath,
  });

  UserProfileState copyWith({
    String? userName,
    String? avatarPath,
  }) {
    return UserProfileState(
      userName: userName ?? this.userName,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  @override
  UserProfileState build() {
    final storage = ref.read(storageServiceProvider);
    return UserProfileState(
      userName: storage.getSetting(AppConstants.userNameKey),
      avatarPath: storage.getSetting(AppConstants.userAvatarPathKey),
    );
  }

  Future<void> updateName(String name) async {
    state = state.copyWith(userName: name);
    await ref.read(storageServiceProvider).saveSetting(
      AppConstants.userNameKey,
      name,
    );
  }

  Future<void> updateAvatar(String? path) async {
    state = state.copyWith(avatarPath: path);
    if (path == null) {
      // Deleting key works better if supported, but saving null is fine if handled
      await ref.read(storageServiceProvider).saveSetting(
        AppConstants.userAvatarPathKey,
        null,
      );
    } else {
      await ref.read(storageServiceProvider).saveSetting(
        AppConstants.userAvatarPathKey,
        path,
      );
    }
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
      UserProfileNotifier.new,
    );
