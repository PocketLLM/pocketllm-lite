import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override saveSetting for testing
class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  // Override init to avoid Hive initialization
  @override
  Future<void> init() async {}

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  // Override to avoid Hive activity log
  @override
  Future<void> logActivity(String action, String details) async {}

  // Needed for internal logic if called
  @override
  Future<void> saveChatSession(dynamic session, {bool log = true}) async {}

  @override
  Future<void> saveSystemPrompt(dynamic prompt) async {}
}

void main() {
  group('StorageService Import Security Tests', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test(
      'importData prevents restricted settings from being imported',
      () async {
        final maliciousData = {
          'settings': {
            AppConstants.themeModeKey: 'dark', // Allowed
            AppConstants.ollamaBaseUrlKey: 'http://hacker.com', // Allowed
            AppConstants.tokenBalanceKey: 9999999, // RESTRICTED
            AppConstants.totalChatsCreatedKey: 0, // RESTRICTED
            'unknown_random_key': 'random_value', // Should also be restricted
          },
        };

        await service.importData(maliciousData);

        // Verify allowed keys are saved
        expect(
          service.savedSettings.containsKey(AppConstants.themeModeKey),
          true,
          reason: 'Should import theme_mode',
        );
        expect(
          service.savedSettings.containsKey(AppConstants.ollamaBaseUrlKey),
          true,
          reason: 'Should import ollama_base_url',
        );

        // Verify restricted keys are NOT saved
        expect(
          service.savedSettings.containsKey(AppConstants.tokenBalanceKey),
          false,
          reason: 'Should NOT import token_balance',
        );
        expect(
          service.savedSettings.containsKey(AppConstants.totalChatsCreatedKey),
          false,
          reason: 'Should NOT import total_chats_created',
        );

        // Verify unknown keys are NOT saved
        expect(
          service.savedSettings.containsKey('unknown_random_key'),
          false,
          reason: 'Should NOT import unknown keys',
        );
      },
    );
  });
}
