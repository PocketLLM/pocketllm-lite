import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

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
}

void main() {
  group('StorageService Import Security Tests', () {
    late TestStorageService service;

    setUp(() {
      service = TestStorageService();
    });

    test('importData blocks restricted/unknown keys (Security Fix Verification)', () async {
      final maliciousData = {
        'settings': {
          AppConstants.themeModeKey: 'light', // Allowed
          AppConstants.tokenBalanceKey: 999999, // Restricted
          'unknown_key': 'malicious_value', // Unknown
        }
      };

      await service.importData(maliciousData);

      // Behavior after fix:

      // 1. Allowed key should still be imported
      expect(service.savedSettings[AppConstants.themeModeKey], 'light');

      // 2. Restricted key should NOT be imported
      expect(service.savedSettings.containsKey(AppConstants.tokenBalanceKey), false, reason: 'Restricted key token_balance should be blocked');

      // 3. Unknown key should NOT be imported
      expect(service.savedSettings.containsKey('unknown_key'), false, reason: 'Unknown key should be blocked');
    });
  });
}
