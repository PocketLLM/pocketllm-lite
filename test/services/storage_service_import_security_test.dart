import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  // Override logActivity to avoid Hive dependency
  @override
  Future<void> logActivity(String action, String details) async {}

  // Override getters that might be called during import/init
  @override
  Map<String, dynamic> getExportableSettings() {
    return {};
  }
}

void main() {
  group('StorageService Import Security', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData should filter out restricted settings keys', () async {
      // Prepare malicious data with restricted keys
      final maliciousData = {
        'settings': {
          // Allowed key
          AppConstants.themeModeKey: 'light',

          // Restricted keys (Usage Limits)
          AppConstants.tokenBalanceKey: 1000000,
          AppConstants.totalTokensUsedKey: 0,
          AppConstants.enhancerUsesTodayKey: 0,
          AppConstants.totalChatsCreatedKey: 0,

          // Unknown/Random key
          'random_malicious_flag': true,
        }
      };

      await service.importData(maliciousData);

      // Verify allowed key is saved
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.savedSettings[AppConstants.themeModeKey], 'light');

      // Verify restricted keys are NOT saved
      expect(
        service.savedSettings.containsKey(AppConstants.tokenBalanceKey),
        isFalse,
        reason: 'Should not import token_balance'
      );
      expect(
        service.savedSettings.containsKey(AppConstants.totalTokensUsedKey),
        isFalse,
        reason: 'Should not import total_tokens_used'
      );
      expect(
        service.savedSettings.containsKey(AppConstants.enhancerUsesTodayKey),
        isFalse,
        reason: 'Should not import enhancer_uses_today'
      );
      expect(
        service.savedSettings.containsKey(AppConstants.totalChatsCreatedKey),
        isFalse,
        reason: 'Should not import total_chats_created'
      );

      // Verify random key is NOT saved (whitelist approach)
      expect(
        service.savedSettings.containsKey('random_malicious_flag'),
        isFalse,
        reason: 'Should not import unknown keys'
      );
    });

    test('importData should allow model settings (prefix match)', () async {
      final data = {
        'settings': {
          '${AppConstants.modelSettingsPrefixKey}some_model_config': {'temp': 0.7},
        }
      };

      await service.importData(data);

      expect(
        service.savedSettings.containsKey('${AppConstants.modelSettingsPrefixKey}some_model_config'),
        isTrue
      );
    });
  });
}
