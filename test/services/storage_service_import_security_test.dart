import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  @override
  Future<void> init() async {
    // No-op
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }

  // Override to prevent Hive box access
  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  Future<void> saveSystemPrompt(SystemPrompt prompt) async {}
}

void main() {
  group('StorageService Import Security', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('should only import allowed settings', () async {
      final maliciousData = {
        'settings': {
          // Allowed keys
          AppConstants.themeModeKey: 'dark',
          AppConstants.ollamaBaseUrlKey: 'http://malicious.url',
          'model_settings_llama3': {'temperature': 0.7},

          // Forbidden keys (Usage limits, etc.)
          AppConstants.tokenBalanceKey: 1000000,
          AppConstants.totalTokensUsedKey: 0,
          AppConstants.isFirstLaunchKey: false,
          'some_internal_flag': true,
        }
      };

      await service.importData(maliciousData);

      // Verify allowed keys are saved
      expect(service.savedSettings, containsPair(AppConstants.themeModeKey, 'dark'));
      expect(service.savedSettings, containsPair(AppConstants.ollamaBaseUrlKey, 'http://malicious.url'));
      expect(service.savedSettings.containsKey('model_settings_llama3'), isTrue);

      // Verify forbidden keys are NOT saved
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Should not import token_balance');
      expect(service.savedSettings.containsKey(AppConstants.totalTokensUsedKey), isFalse, reason: 'Should not import total_tokens_used');
      expect(service.savedSettings.containsKey(AppConstants.isFirstLaunchKey), isFalse, reason: 'Should not import is_first_launch');
      expect(service.savedSettings.containsKey('some_internal_flag'), isFalse);
    });
  });
}
