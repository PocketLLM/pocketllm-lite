import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class AppearanceState {
  final int userMsgColor;
  final int aiMsgColor;
  final double bubbleRadius;
  final double fontSize;

  AppearanceState({
    required this.userMsgColor,
    required this.aiMsgColor,
    required this.bubbleRadius,
    required this.fontSize,
  });

  AppearanceState copyWith({
    int? userMsgColor,
    int? aiMsgColor,
    double? bubbleRadius,
    double? fontSize,
  }) {
    return AppearanceState(
      userMsgColor: userMsgColor ?? this.userMsgColor,
      aiMsgColor: aiMsgColor ?? this.aiMsgColor,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class AppearanceNotifier extends Notifier<AppearanceState> {
  @override
  AppearanceState build() {
    final storage = ref.read(storageServiceProvider);
    return AppearanceState(
      userMsgColor: storage.getSetting(
        AppConstants.userMsgColorKey,
        defaultValue: Colors.teal.value,
      ),
      aiMsgColor: storage.getSetting(
        AppConstants.aiMsgColorKey,
        defaultValue: Colors.grey[800]?.value ?? Colors.grey.value,
      ),
      // Note: Default AI color logic is tricky if light/dark mode changes.
      // We might want to store "null" to mean "use theme default".
      // For now, let's assume a dark grey/surface variant.
      bubbleRadius: storage.getSetting(
        AppConstants.bubbleRadiusKey,
        defaultValue: 12.0,
      ),
      fontSize: storage.getSetting(
        AppConstants.fontSizeKey,
        defaultValue: 16.0,
      ),
    );
  }

  Future<void> updateUserMsgColor(int color) async {
    state = state.copyWith(userMsgColor: color);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.userMsgColorKey, color);
  }

  Future<void> updateAiMsgColor(int color) async {
    state = state.copyWith(aiMsgColor: color);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.aiMsgColorKey, color);
  }

  Future<void> updateBubbleRadius(double radius) async {
    state = state.copyWith(bubbleRadius: radius);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.bubbleRadiusKey, radius);
  }

  Future<void> updateFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.fontSizeKey, size);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
      AppearanceNotifier.new,
    );
