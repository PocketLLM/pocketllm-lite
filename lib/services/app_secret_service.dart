import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/app_constants.dart';
import 'storage_service.dart';

class AppSecretService {
  static const String _tavilyKey = 'tavily_api_key_v1';
  final FlutterSecureStorage _storage;

  const AppSecretService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> getTavilyApiKey() => _storage.read(key: _tavilyKey);

  Future<void> setTavilyApiKey(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: _tavilyKey);
    } else {
      await _storage.write(key: _tavilyKey, value: normalized);
    }
  }

  Future<void> migrateLegacySecrets(StorageService storage) async {
    final legacy = storage.getSetting(AppConstants.tavilyApiKeyKey);
    if (legacy is String && legacy.trim().isNotEmpty) {
      final existing = await getTavilyApiKey();
      if (existing == null || existing.isEmpty) {
        await setTavilyApiKey(legacy);
      }
    }
    await storage.deleteSetting(AppConstants.tavilyApiKeyKey);
  }
}
