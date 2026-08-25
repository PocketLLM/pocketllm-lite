import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/app_secret_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class _LegacySecretStorage extends StorageService {
  final Map<String, dynamic> values;

  _LegacySecretStorage(this.values);

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('moves a legacy Tavily key into secure storage and deletes plaintext',
      () async {
    final legacy = _LegacySecretStorage({
      AppConstants.tavilyApiKeyKey: 'tvly-secret-value',
    });
    const secrets = AppSecretService();

    await secrets.migrateLegacySecrets(legacy);

    expect(await secrets.getTavilyApiKey(), 'tvly-secret-value');
    expect(legacy.values, isNot(contains(AppConstants.tavilyApiKeyKey)));
  });

  test('empty secure values are deleted instead of stored', () async {
    const secrets = AppSecretService();
    await secrets.setTavilyApiKey('tvly-secret-value');
    await secrets.setTavilyApiKey('   ');

    expect(await secrets.getTavilyApiKey(), isNull);
  });
}
