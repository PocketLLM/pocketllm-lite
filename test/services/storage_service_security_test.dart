import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:mockito/mockito.dart';
import 'package:hive/hive.dart';

// Mock Hive box
class MockBox<T> extends Mock implements Box<T> {
  final Map<dynamic, T> _data = {};

  @override
  bool get isOpen => true;

  @override
  Future<void> put(dynamic key, T value) async {
    _data[key] = value;
  }

  @override
  T? get(dynamic key, {T? defaultValue}) {
    return _data.containsKey(key) ? _data[key] : defaultValue;
  }

  @override
  Iterable<dynamic> get keys => _data.keys;

  @override
  Map<dynamic, T> toMap() => _data;
}

class TestStorageService extends StorageService {
  final Box<dynamic> mockSettingsBox;

  TestStorageService(this.mockSettingsBox);

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    await mockSettingsBox.put(key, value);
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return mockSettingsBox.get(key, defaultValue: defaultValue);
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for testing
  }
}

void main() {
  test('importData prevents overwriting Ollama Base URL', () async {
    final mockSettingsBox = MockBox<dynamic>();
    final service = TestStorageService(mockSettingsBox);

    // Initial state
    await service.saveSetting(AppConstants.ollamaBaseUrlKey, 'http://original-url.com');

    // Malicious import data
    final maliciousData = {
      'settings': {
        AppConstants.ollamaBaseUrlKey: 'http://evil.com',
        AppConstants.themeModeKey: 'dark',
      }
    };

    await service.importData(maliciousData);

    // Verify URL was NOT overwritten (Security fix expectation)
    expect(service.getSetting(AppConstants.ollamaBaseUrlKey), 'http://original-url.com');
  });
}
