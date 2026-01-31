import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override data accessors for testing
class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  @override
  Future<void> init() async {
    // Bypass Hive init
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for testing
  }

  // Need to override these to avoid Hive errors if called by importData
  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    // No-op
  }

  @override
  Future<void> saveSystemPrompt(prompt) async {
    // No-op
  }
}

void main() {
  group('StorageService Import Security Tests', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData prevents restricted settings from being imported', () async {
      // Create import data with mixed allowed and restricted keys
      final importData = {
        'settings': {
          AppConstants.themeModeKey: 'light', // Allowed
          AppConstants.tokenBalanceKey: 9999999, // Restricted
          'unknown_key': 'some_value', // Unknown (should be blocked)
        }
      };

      await service.importData(importData);

      // Verify allowed keys are saved
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.savedSettings[AppConstants.themeModeKey], 'light');

      // Verify restricted keys are NOT saved
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse,
        reason: 'Restricted key ${AppConstants.tokenBalanceKey} should not be imported');

      // Verify unknown keys are NOT saved
      expect(service.savedSettings.containsKey('unknown_key'), isFalse,
        reason: 'Unknown keys should not be imported');
    });

    test('importData allows model settings keys', () async {
      final importData = {
        'settings': {
          '${AppConstants.modelSettingsPrefixKey}llama3': {'temperature': 0.7},
        }
      };

      await service.importData(importData);

      expect(service.savedSettings.keys, contains('${AppConstants.modelSettingsPrefixKey}llama3'));
    });
  });
}
