import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> storedSettings = {};

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    storedSettings[key] = value;
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
  group('StorageService Import Security Test', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData blocks restricted keys and allows valid keys', () async {
      final data = {
        'settings': {
          AppConstants.tokenBalanceKey: 9999999,
          AppConstants.themeModeKey: 'dark',
          '${AppConstants.modelSettingsPrefixKey}llama2': {'temperature': 0.7},
        },
      };

      await service.importData(data);

      // Verify restricted key is BLOCKED
      expect(
        service.storedSettings.containsKey(AppConstants.tokenBalanceKey),
        isFalse,
        reason: 'Restricted key should be blocked',
      );

      // Verify valid key is IMPORTED
      expect(
        service.storedSettings.containsKey(AppConstants.themeModeKey),
        isTrue,
      );
      expect(service.storedSettings[AppConstants.themeModeKey], 'dark');

      // Verify model setting (prefix match) is IMPORTED
      expect(
        service.storedSettings.containsKey(
          '${AppConstants.modelSettingsPrefixKey}llama2',
        ),
        isTrue,
      );
    });
  });
}
