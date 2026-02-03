import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final Map<String, dynamic> storedSettings = {};

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    storedSettings[key] = value;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return storedSettings[key] ?? defaultValue;
  }

  @override
  Future<void> logActivity(String action, String details) async {}
}

void main() {
  test('importData should reject restricted settings keys', () async {
    final service = MockStorageService();

    final maliciousData = {
      'settings': {
        AppConstants.themeModeKey: 'dark', // Allowed
        AppConstants.tokenBalanceKey: 999999, // RESTRICTED
        'random_garbage_key': 'garbage', // RESTRICTED
      }
    };

    await service.importData(maliciousData);

    expect(service.storedSettings.containsKey(AppConstants.themeModeKey), true);
    expect(service.storedSettings.containsKey(AppConstants.tokenBalanceKey), false, reason: 'Should not import token_balance');
    expect(service.storedSettings.containsKey('random_garbage_key'), false, reason: 'Should not import unknown keys');
  });
}
