import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass for testing import logic without Hive
class ImportTestStorageService extends StorageService {
  final Map<String, dynamic> storedSettings = {};

  @override
  Future<void> init() async {
    // Bypass Hive init
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    storedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }

  @override
  Future<void> saveSystemPrompt(SystemPrompt prompt) async {
    // No-op
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    // No-op
  }
}

void main() {
  group('StorageService Import Security', () {
    late ImportTestStorageService service;

    setUp(() async {
      service = ImportTestStorageService();
      await service.init();
    });

    test('importData prevents restricted keys from being imported', () async {
      final maliciousData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'settings': {
          AppConstants.themeModeKey: 'dark', // Allowed
          AppConstants.tokenBalanceKey: 999999, // Restricted!
          'unknown_random_key': 'malicious_value', // Restricted (not in whitelist)
        }
      };

      await service.importData(maliciousData);

      // Verify allowed key is present
      expect(service.storedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.storedSettings[AppConstants.themeModeKey], 'dark');

      // Verify restricted keys are ABSENT
      expect(service.storedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Restricted key token_balance was imported!');
      expect(service.storedSettings.containsKey('unknown_random_key'), isFalse);
    });

    test('importData allows model settings keys', () async {
       final validData = {
        'version': 1,
        'settings': {
          '${AppConstants.modelSettingsPrefixKey}llama3': {'temp': 0.7},
        }
      };

      await service.importData(validData);

      expect(service.storedSettings.containsKey('${AppConstants.modelSettingsPrefixKey}llama3'), isTrue);
    });
  });
}
