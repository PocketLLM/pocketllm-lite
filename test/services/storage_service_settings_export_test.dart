import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override data accessors for testing
class TestStorageService extends StorageService {
  final Map<String, dynamic> _mockSettings;

  TestStorageService(this._mockSettings);

  @override
  List<ChatSession> getChatSessions() {
    return [];
  }

  @override
  Map<String, dynamic> getExportableSettings() {
    return _mockSettings;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for testing
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
     // Mock save
  }
}

void main() {
  group('StorageService Settings Export Tests', () {
    late TestStorageService service;
    late Map<String, dynamic> mockSettings;

    setUp(() {
      mockSettings = {
        'theme_mode': 'dark',
        'ollama_base_url': 'http://test.local',
        'font_size': 14.0,
      };
      service = TestStorageService(mockSettings);
    });

    test('exportData includes settings when requested', () {
      final result = service.exportData(
        includeChats: false,
        includePrompts: false,
        includeSettings: true
      );

      expect(result['settings'], isNotNull);
      final settings = result['settings'] as Map<String, dynamic>;
      expect(settings['theme_mode'], 'dark');
      expect(settings['ollama_base_url'], 'http://test.local');
    });

    test('exportData excludes settings when not requested', () {
      final result = service.exportData(
        includeChats: false,
        includePrompts: false,
        includeSettings: false
      );

      expect(result['settings'], isNull);
    });

    test('exportData excludes settings by default', () {
      final result = service.exportData(
        includeChats: false,
        includePrompts: false,
      );

      expect(result['settings'], isNull);
    });
  });
}
