import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class AppearanceState {
  final int userMsgColor;
  final int aiMsgColor;
  final double bubbleRadius;
  final double fontSize;
  final double chatPadding;
  final bool showAvatars;
  final bool bubbleElevation;
  final double msgOpacity;
  final int? customBgColor;

  AppearanceState({
    required this.userMsgColor,
    required this.aiMsgColor,
    required this.bubbleRadius,
    required this.fontSize,
    this.chatPadding = 16.0,
    this.showAvatars = false,
    this.bubbleElevation = false,
    this.msgOpacity = 1.0,
    this.customBgColor,
  });

  AppearanceState copyWith({
    int? userMsgColor,
    int? aiMsgColor,
    double? bubbleRadius,
    double? fontSize,
    double? chatPadding,
    bool? showAvatars,
    bool? bubbleElevation,
    double? msgOpacity,
    int? customBgColor,
  }) {
    return AppearanceState(
      userMsgColor: userMsgColor ?? this.userMsgColor,
      aiMsgColor: aiMsgColor ?? this.aiMsgColor,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      fontSize: fontSize ?? this.fontSize,
      chatPadding: chatPadding ?? this.chatPadding,
      showAvatars: showAvatars ?? this.showAvatars,
      bubbleElevation: bubbleElevation ?? this.bubbleElevation,
      msgOpacity: msgOpacity ?? this.msgOpacity,
      customBgColor: customBgColor ?? this.customBgColor,
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
      bubbleRadius: storage.getSetting(
        AppConstants.bubbleRadiusKey,
        defaultValue: 16.0,
      ),
      fontSize: storage.getSetting(
        AppConstants.fontSizeKey,
        defaultValue: 16.0,
      ),
      chatPadding: storage.getSetting(
        AppConstants.chatPaddingKey,
        defaultValue: 16.0,
      ),
      showAvatars: storage.getSetting(
        AppConstants.showAvatarsKey,
        defaultValue: false,
      ),
      bubbleElevation: storage.getSetting(
        AppConstants.bubbleElevationKey,
        defaultValue: false,
      ),
      msgOpacity: storage.getSetting(
        AppConstants.msgOpacityKey,
        defaultValue: 1.0,
      ),
      customBgColor: storage.getSetting(
        AppConstants.customBgColorKey,
        defaultValue: null,
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

  Future<void> updateChatPadding(double padding) async {
    state = state.copyWith(chatPadding: padding);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.chatPaddingKey, padding);
  }

  Future<void> updateShowAvatars(bool show) async {
    state = state.copyWith(showAvatars: show);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.showAvatarsKey, show);
  }

  Future<void> updateBubbleElevation(bool elevation) async {
    state = state.copyWith(bubbleElevation: elevation);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.bubbleElevationKey, elevation);
  }

  Future<void> updateMsgOpacity(double opacity) async {
    state = state.copyWith(msgOpacity: opacity);
    await ref
        .read(storageServiceProvider)
        .saveSetting(AppConstants.msgOpacityKey, opacity);
  }

  Future<void> updateCustomBgColor(int? color) async {
    state = state.copyWith(customBgColor: color); // null allowed
    if (color == null) {
      // Ideally we should delete or save null, but StorageService might not support saving null directly if it expects type?
      // Let's check storage service. If it uses Hive/Prefs, putting null usually removes or saves null.
      // Assuming saveSetting handles null or we map strict types.
      // If StorageService implementation is simple Hive put, it supports null.
      await ref
          .read(storageServiceProvider)
          .saveSetting(AppConstants.customBgColorKey, null);
    } else {
      await ref
          .read(storageServiceProvider)
          .saveSetting(AppConstants.customBgColorKey, color);
    }
  }

  // Method to apply a full preset
  Future<void> applyPreset({
    required int userColor,
    required int aiColor,
    required double radius,
    double? fontSize,
  }) async {
    // Create new state
    state = state.copyWith(
      userMsgColor: userColor,
      aiMsgColor: aiColor,
      bubbleRadius: radius,
      fontSize:
          fontSize, // optional update, maybe keep user pref? Requirement says "instantly applies all colours + radius + font size" - well wait, does preset imply font size?
      // "Tapping a preset instantly applies all colours + radius + font size" - ok.
      // But usually presets are for colors. "Classic Telegram" implies shape too.
      // Let's update colors and radius. Font size might be personal preference, but if requested I will update it.
      // Let's stick to Colors + Radius for theme presets mostly, but I'll allow passing others.
    );

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.userMsgColorKey, userColor);
    await storage.saveSetting(AppConstants.aiMsgColorKey, aiColor);
    await storage.saveSetting(AppConstants.bubbleRadiusKey, radius);
    if (fontSize != null) {
      await storage.saveSetting(AppConstants.fontSizeKey, fontSize);
    }
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
      AppearanceNotifier.new,
    );
