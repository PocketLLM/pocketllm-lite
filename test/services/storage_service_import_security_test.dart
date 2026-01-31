import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> memorySettings = {};

  @override
  Future<void> init() async {
    // Skip Hive initialization
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    memorySettings[key] = value;
  }

  // Override to prevent Hive access during import
  @override
  Future<void> logActivity(String action, String details) async {}

  // Override to prevent Hive access during import if chats are included (we won't include them in this test)
  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}
}

void main() {
  group('StorageService Import Security', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('Vulnerability Check: importData currently allows restricted keys', () async {
      // restricted key that should NOT be importable
      const restrictedKey = AppConstants.tokenBalanceKey; // 'token_balance'
      const restrictedValue = 99999;

      final data = {
        'settings': {
          restrictedKey: restrictedValue,
          AppConstants.themeModeKey: 'light', // allowed key
        }
      };

      await service.importData(data);

      // AFTER FIX: Restricted keys should be filtered out.
      expect(service.memorySettings.containsKey(restrictedKey), isFalse,
        reason: 'Restricted key should NOT be imported (Fix verified)');

      // Allowed key should also be present
      expect(service.memorySettings[AppConstants.themeModeKey], 'light');
    });
  });
}
