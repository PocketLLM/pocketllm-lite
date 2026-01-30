import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

  @override
  Future<void> init() async {
    // No-op: Bypass Hive initialization
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    savedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op: Bypass logging
  }
}

void main() {
  group('StorageService Security Import Tests', () {
    late MockStorageService service;

    setUp(() {
      service = MockStorageService();
    });

    test('importData allows restricted keys (VULNERABILITY REPRODUCTION)', () async {
      // Create a malicious payload with restricted keys
      final maliciousData = {
        'settings': {
          AppConstants.themeModeKey: 'dark', // Allowed
          AppConstants.tokenBalanceKey: 9999999, // Restricted!
          AppConstants.totalTokensUsedKey: 0, // Restricted!
        }
      };

      await service.importData(maliciousData);

      // Verify restricted keys were NOT saved
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Security Fix: token_balance should be filtered');
      expect(service.savedSettings.containsKey(AppConstants.totalTokensUsedKey), isFalse, reason: 'Security Fix: total_tokens_used should be filtered');

      // Verify allowed keys were saved
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), isTrue);
    });
  });
}
