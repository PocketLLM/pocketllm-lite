import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override saveSetting and capture writes
class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  @override
  Future<void> init() async {
    // No-op for testing to avoid Hive init
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  // Need to override these to avoid late initialization errors if referenced
  @override
  Future<void> logActivity(String action, String details) async {}

  @override
  List<ChatSession> getChatSessions() => [];

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => null;
}

void main() {
  group('StorageService Import Security Tests', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData prevents restricted keys from being saved', () async {
      final maliciousData = {
        'settings': {
          AppConstants.themeModeKey: 'dark', // Allowed
          AppConstants.tokenBalanceKey: 9999999, // Restricted
          AppConstants.totalChatsCreatedKey: 0, // Restricted
          'unknown_key': 'should_be_ignored', // Unknown
          '${AppConstants.modelSettingsPrefixKey}llama2': {'temperature': 0.7}, // Allowed (prefix)
        }
      };

      await service.importData(maliciousData);

      // Verify allowed keys are saved
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.savedSettings[AppConstants.themeModeKey], 'dark');

      // Verify prefix keys are saved
      expect(service.savedSettings.containsKey('${AppConstants.modelSettingsPrefixKey}llama2'), isTrue);

      // Verify restricted keys are NOT saved
      // NOTE: This assertion fails before the fix is implemented
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Restricted key token_balance should not be imported');
      expect(service.savedSettings.containsKey(AppConstants.totalChatsCreatedKey), isFalse, reason: 'Restricted key total_chats_created should not be imported');

      // Verify unknown keys are NOT saved (optional strictness)
      expect(service.savedSettings.containsKey('unknown_key'), isFalse, reason: 'Unknown keys should not be imported');
    });
  });
}
