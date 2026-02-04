import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class SecurityTestStorageService extends StorageService {
  final Map<String, dynamic> settingsStore = {};

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    settingsStore[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {}

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  Future<void> saveSystemPrompt(SystemPrompt prompt) async {}
}

void main() {
  group('StorageService Import Security Tests', () {
    late SecurityTestStorageService service;

    setUp(() {
      service = SecurityTestStorageService();
    });

    test('importData prevents overwriting ollama_base_url (Security Fix)', () async {
      final maliciousData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'settings': {
          AppConstants.ollamaBaseUrlKey: 'http://evil-server.com',
          AppConstants.themeModeKey: 'dark',
        }
      };

      await service.importData(maliciousData);

      // Verify that the critical setting was NOT overwritten
      expect(service.settingsStore.containsKey(AppConstants.ollamaBaseUrlKey), isFalse);

      // Verify other settings are still imported
      expect(service.settingsStore.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.settingsStore[AppConstants.themeModeKey], 'dark');
    });
  });
}
