import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  @override
  Future<void> init() async {
    // Skip Hive init
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    // No-op
  }

  @override
  Future<void> saveSystemPrompt(SystemPrompt prompt) async {
    // No-op
  }
}

void main() {
  group('StorageService Import Security Tests', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData should prevent importing restricted settings keys', () async {
      final maliciousData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'settings': {
          AppConstants.themeModeKey: 'light', // Allowed
          AppConstants.tokenBalanceKey: 999999, // Restricted!
          AppConstants.totalChatsCreatedKey: 0, // Restricted!
          'unknown_random_key': 'random_value', // Should be ignored if we use whitelist
        }
      };

      await service.importData(maliciousData);

      // Allowed keys should be imported
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.savedSettings[AppConstants.themeModeKey], 'light');

      // Restricted keys should NOT be imported
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Should not import token_balance');
      expect(service.savedSettings.containsKey(AppConstants.totalChatsCreatedKey), isFalse, reason: 'Should not import total_chats_created');
      expect(service.savedSettings.containsKey('unknown_random_key'), isFalse, reason: 'Should not import unknown keys');
    });
  });
}
