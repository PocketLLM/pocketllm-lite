import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class ProfileState {
  final String name;
  final String bio;
  final int avatarColor;
  final String? avatarImageBase64;

  const ProfileState({
    required this.name,
    required this.bio,
    required this.avatarColor,
    this.avatarImageBase64,
  });

  ProfileState copyWith({
    String? name,
    String? bio,
    int? avatarColor,
    String? avatarImageBase64,
  }) {
    return ProfileState(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarImageBase64: avatarImageBase64 ?? this.avatarImageBase64,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    final storage = ref.read(storageServiceProvider);
    return ProfileState(
      name: storage.getSetting(AppConstants.profileNameKey, defaultValue: ''),
      bio: storage.getSetting(AppConstants.profileBioKey, defaultValue: ''),
      avatarColor: storage.getSetting(
        AppConstants.profileAvatarColorKey,
        defaultValue: Colors.blue.toARGB32(),
      ),
      avatarImageBase64: storage.getSetting(
        AppConstants.profileAvatarImageKey,
        defaultValue: null,
      ),
    );
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    int? avatarColor,
    String? avatarImageBase64,
  }) async {
    final storage = ref.read(storageServiceProvider);

    if (name != null) {
      await storage.saveSetting(AppConstants.profileNameKey, name);
    }
    if (bio != null) {
      await storage.saveSetting(AppConstants.profileBioKey, bio);
    }
    if (avatarColor != null) {
      await storage.saveSetting(
        AppConstants.profileAvatarColorKey,
        avatarColor,
      );
    }
    // Handle avatar image update: if passed as null (and explicitly wanting to clear),
    // we need a way to distinguish "no update" vs "clear".
    // For now, if caller passes null, it means no update.
    // We can add a separate clear method or specific logic.
    // BUT copyWith logic above implies null = keep existing.
    // So to clear, we might need a separate method or flag.
    // Or we pass `avatarImageBase64` as nullable, but how to signify "keep existing"?
    // In `updateProfile`, if argument is null, we assume no change.
    // If we want to clear, we can pass empty string? Or have `clearAvatarImage` method.

    // Let's assume non-null updates. For clearing, we'll add `removeAvatarImage`.
    if (avatarImageBase64 != null) {
      await storage.saveSetting(
        AppConstants.profileAvatarImageKey,
        avatarImageBase64,
      );
    }

    state = state.copyWith(
      name: name,
      bio: bio,
      avatarColor: avatarColor,
      avatarImageBase64: avatarImageBase64,
    );
  }

  Future<void> removeAvatarImage() async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.profileAvatarImageKey, null);

    // We need to construct a new state where avatarImageBase64 is null.
    // copyWith doesn't support setting to null if the argument is null (it keeps existing).
    // So we reconstruct.
    state = ProfileState(
      name: state.name,
      bio: state.bio,
      avatarColor: state.avatarColor,
      avatarImageBase64: null,
    );
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
