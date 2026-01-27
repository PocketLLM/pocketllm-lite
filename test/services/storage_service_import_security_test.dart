import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override persistence logic
class SecurityTestStorageService extends StorageService {
  final Map<String, dynamic> settingsMap = {};

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    settingsMap[key] = value;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsMap.containsKey(key) ? settingsMap[key] : defaultValue;
  }

  // Stubs for other methods called by importData
  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  Future<void> saveSystemPrompt(SystemPrompt prompt) async {}

  @override
  Future<void> logActivity(String action, String details) async {}
}

void main() {
  group('StorageService Import Security', () {
    late SecurityTestStorageService service;

    setUp(() {
      service = SecurityTestStorageService();
    });

    test('SECURITY: importData prevents injecting non-exportable settings', () async {
      // The payload contains a restricted key 'token_balance' (used for monetization/limits)
      // and an allowed key 'theme_mode'.
      final maliciousPayload = {
        'settings': {
          AppConstants.tokenBalanceKey: 999999, // Should be blocked
          AppConstants.themeModeKey: 'light',     // Should be allowed
        }
      };

      await service.importData(maliciousPayload);

      // Verify legitimate setting is imported
      expect(service.getSetting(AppConstants.themeModeKey), equals('light'));

      // Verify malicious setting is NOT imported (security fix)
      expect(service.getSetting(AppConstants.tokenBalanceKey), isNull);
    });
  });
}
