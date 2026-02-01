import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to intercept writes
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
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    // No-op
  }

  @override
  Future<void> saveSystemPrompt(SystemPrompt prompt) async {
    // No-op
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }
}

void main() {
  group('StorageService Import Security Tests', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData rejects restricted keys (Vulnerability Fix Verification)', () async {
      // Malicious payload trying to reset token balance and increase limits
      final maliciousData = {
        'settings': {
          AppConstants.tokenBalanceKey: 999999,
          AppConstants.totalChatsCreatedKey: 0,
          AppConstants.themeModeKey: 'light', // Valid key
          'model_settings_gpt4': {'foo': 'bar'}, // Valid key prefix
        }
      };

      await service.importData(maliciousData);

      // Verify that the restricted keys were NOT saved
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Token balance should not be importable');
      expect(service.savedSettings.containsKey(AppConstants.totalChatsCreatedKey), isFalse, reason: 'Total chats created should not be importable');

      // Valid key should be saved
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), isTrue, reason: 'Theme mode should be importable');

      // Valid prefix should be saved
      expect(service.savedSettings.containsKey('model_settings_gpt4'), isTrue, reason: 'Model settings should be importable');
    });
  });
}
