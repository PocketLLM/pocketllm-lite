import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class SecurityTestStorageService extends StorageService {
  final Map<String, dynamic> storedSettings = {};

  @override
  Future<void> init() async {
    // Skip Hive init
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    storedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }
}

void main() {
  group('StorageService Import Security Tests', () {
    late SecurityTestStorageService service;

    setUp(() {
      service = SecurityTestStorageService();
    });

    test('importData should only import allowed settings', () async {
      final maliciousData = {
        'settings': {
          // Allowed keys
          AppConstants.themeModeKey: 'light',
          AppConstants.ollamaBaseUrlKey: 'http://hacker.com',

          // Restricted keys (Business Logic / Limits)
          AppConstants.tokenBalanceKey: 1000000,
          AppConstants.totalChatsCreatedKey: 0,

          // Random keys
          'some_random_injection': 'malicious_value',
        }
      };

      await service.importData(maliciousData);

      // Verify allowed keys are imported
      expect(service.storedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.storedSettings[AppConstants.themeModeKey], 'light');

      expect(service.storedSettings.containsKey(AppConstants.ollamaBaseUrlKey), isTrue);
      expect(service.storedSettings[AppConstants.ollamaBaseUrlKey], 'http://hacker.com');

      // Verify restricted keys are BLOCKED
      // This expectation will FAIL before the fix
      expect(service.storedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse,
        reason: 'Should not import restricted key: ${AppConstants.tokenBalanceKey}');

      expect(service.storedSettings.containsKey(AppConstants.totalChatsCreatedKey), isFalse,
        reason: 'Should not import restricted key: ${AppConstants.totalChatsCreatedKey}');

      expect(service.storedSettings.containsKey('some_random_injection'), isFalse,
        reason: 'Should not import unknown keys');
    });

    test('importData allows model settings with prefix', () async {
       final data = {
        'settings': {
          'model_settings_llama3': {'temperature': 0.7},
          'model_settings_mistral': {'top_k': 40},
        }
      };

      await service.importData(data);

      expect(service.storedSettings.containsKey('model_settings_llama3'), isTrue);
      expect(service.storedSettings.containsKey('model_settings_mistral'), isTrue);
    });
  });
}
