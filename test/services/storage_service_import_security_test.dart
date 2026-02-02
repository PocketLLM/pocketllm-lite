import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> storedSettings = {};

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    storedSettings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // no-op
  }
}

void main() {
  group('StorageService Import Security', () {
    test('should prevent import of restricted keys (e.g. usage limits)', () async {
      final service = TestStorageService();

      final maliciousData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'settings': {
          AppConstants.themeModeKey: 'dark', // Allowed
          AppConstants.tokenBalanceKey: 1000000, // Restricted!
          'unknown_key': 'malicious_value', // Restricted!
        }
      };

      await service.importData(maliciousData);

      // Verify allowed key is imported
      expect(service.storedSettings.containsKey(AppConstants.themeModeKey), isTrue);
      expect(service.storedSettings[AppConstants.themeModeKey], 'dark');

      // Verify restricted keys are NOT imported
      // This expectation will FAIL currently, verifying the vulnerability
      expect(service.storedSettings.containsKey(AppConstants.tokenBalanceKey), isFalse, reason: 'Restricted key token_balance was imported!');
      expect(service.storedSettings.containsKey('unknown_key'), isFalse, reason: 'Unknown key was imported!');
    });
  });
}
