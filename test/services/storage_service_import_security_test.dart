import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> savedSettings = {};

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

    test('importData currently allows importing restricted settings (Vulnerability Check)', () async {
      final data = {
        'settings': {
          AppConstants.themeModeKey: 'dark', // Allowed
          AppConstants.totalTokensUsedKey: 999999, // Restricted
          'random_garbage_key': 'malicious_value', // Garbage
        }
      };

      await service.importData(data);

      // Verify legitimate setting is imported
      expect(service.savedSettings.containsKey(AppConstants.themeModeKey), true);

      // Verify restricted setting is NOT imported (Vulnerability Fixed)
      expect(service.savedSettings.containsKey(AppConstants.totalTokensUsedKey), false);

      // Verify garbage key is NOT imported
      expect(service.savedSettings.containsKey('random_garbage_key'), false);
    });
  });
}
