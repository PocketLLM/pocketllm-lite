import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String ollamaEndpoint;
  final bool isHapticEnabled;
  final String? defaultModelId;
  final double fontSizeScale;
  final bool compressImages;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.ollamaEndpoint = 'http://localhost:11434',
    this.isHapticEnabled = true,
    this.defaultModelId,
    this.fontSizeScale = 1.0,
    this.compressImages = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? ollamaEndpoint,
    bool? isHapticEnabled,
    String? defaultModelId,
    double? fontSizeScale,
    bool? compressImages,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      ollamaEndpoint: ollamaEndpoint ?? this.ollamaEndpoint,
      isHapticEnabled: isHapticEnabled ?? this.isHapticEnabled,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      compressImages: compressImages ?? this.compressImages,
    );
  }
}
