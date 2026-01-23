import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  final Map<String, dynamic> _storage = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _storage[key] ?? defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _storage[key] = value;
  }
}

void main() {
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
  });

  test('AppearanceNotifier loads custom presets from storage', () {
    // Arrange
    final preset = ThemePreset(
      name: 'Test Preset',
      userColor: 0xFF000000,
      aiColor: 0xFFFFFFFF,
      backgroundColor: const Color(0xFF123456),
      note: 'Test Note',
    );
    // Mock save directly to map
    mockStorageService.saveSetting(
      AppConstants.customThemePresetsKey,
      [preset.toJson()],
    );

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
    );

    // Act
    final state = container.read(appearanceProvider);

    // Assert
    expect(state.customPresets.length, 1);
    expect(state.customPresets.first.name, 'Test Preset');
    // Using toARGB32() in logic, but .value in test expectation if matches
    // 0xFF123456 might be negative as int if 32bit? Dart int is 64bit.
    // Color(0xFF...) .value is unsigned in Dart usually? No, it's int.
    expect(state.customPresets.first.backgroundColor.value, 0xFF123456);
  });

  test('AppearanceNotifier saves custom preset', () async {
    // Arrange
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
    );
    final notifier = container.read(appearanceProvider.notifier);

    // Act
    final preset = ThemePreset(
      name: 'New Preset',
      userColor: 0xFF111111,
      aiColor: 0xFF222222,
      backgroundColor: const Color(0xFF333333),
      note: 'New Note',
    );
    await notifier.saveCustomPreset(preset);

    // Assert
    final state = container.read(appearanceProvider);
    expect(state.customPresets.length, 1);
    expect(state.customPresets.first.name, 'New Preset');

    // Verify storage
    final stored = mockStorageService.getSetting(AppConstants.customThemePresetsKey) as List;
    expect(stored.length, 1);
    expect(stored.first['name'], 'New Preset');
  });

  test('AppearanceNotifier deletes custom preset', () async {
    // Arrange
    final preset = ThemePreset(
      name: 'Delete Me',
      userColor: 0,
      aiColor: 0,
      backgroundColor: Colors.black,
      note: '',
    );
    await mockStorageService.saveSetting(
      AppConstants.customThemePresetsKey,
      [preset.toJson()],
    );

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
    );
    final notifier = container.read(appearanceProvider.notifier);

    // Act
    await notifier.deleteCustomPreset('Delete Me');

    // Assert
    final state = container.read(appearanceProvider);
    expect(state.customPresets.isEmpty, true);

    final stored = mockStorageService.getSetting(AppConstants.customThemePresetsKey) as List;
    expect(stored.isEmpty, true);
  });
}
