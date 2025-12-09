import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

part 'settings_provider.g.dart';

@riverpod
class Settings extends _$Settings {
  static const _keyTheme = 'theme_mode';
  static const _keyEndpoint = 'ollama_endpoint';
  static const _keyHaptic = 'is_haptic_enabled';
  static const _keyDefaultModel = 'default_model_id';
  static const _keyFontSize = 'font_size_scale';
  static const _keyCompressImages = 'compress_images';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();

    final themeIndex = prefs.getInt(_keyTheme) ?? 0;
    final endpoint = prefs.getString(_keyEndpoint) ?? 'http://localhost:11434';
    final haptic = prefs.getBool(_keyHaptic) ?? true;
    final defaultModel = prefs.getString(_keyDefaultModel);
    final fontSize = prefs.getDouble(_keyFontSize) ?? 1.0;
    final compress = prefs.getBool(_keyCompressImages) ?? false;

    return AppSettings(
      themeMode: ThemeMode.values[themeIndex],
      ollamaEndpoint: endpoint,
      isHapticEnabled: haptic,
      defaultModelId: defaultModel,
      fontSizeScale: fontSize,
      compressImages: compress,
    );
  }

  Future<void> updateTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, mode.index);
    state = AsyncData(state.value!.copyWith(themeMode: mode));
  }

  Future<void> updateEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndpoint, endpoint);
    state = AsyncData(state.value!.copyWith(ollamaEndpoint: endpoint));
  }

  Future<void> toggleHaptic(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptic, enabled);
    state = AsyncData(state.value!.copyWith(isHapticEnabled: enabled));
  }

  Future<void> setDefaultModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultModel, modelId);
    state = AsyncData(state.value!.copyWith(defaultModelId: modelId));
  }

  Future<void> updateFontSize(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, scale);
    state = AsyncData(state.value!.copyWith(fontSizeScale: scale));
  }

  Future<void> toggleCompressImages(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompressImages, enabled);
    state = AsyncData(state.value!.copyWith(compressImages: enabled));
  }
}
