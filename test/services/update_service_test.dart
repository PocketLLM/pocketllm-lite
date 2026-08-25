import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/services/update_service.dart';

class _UpdatePolicyStorage extends StorageService {
  final Map<String, dynamic> values = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    values[key] = value;
  }
}

void main() {
  setUp(() {
    NetworkPolicyService().init(_UpdatePolicyStorage());
  });

  test('release metadata pairs APK with a published checksum asset', () {
    final release = AppRelease.fromJson({
      'tag_name': 'v1.0.36',
      'name': 'PocketLLM Lite 1.0.36',
      'body': 'Verified release',
      'published_at': '2026-08-25T12:00:00Z',
      'assets': [
        {
          'name': 'PocketLLM-Lite-v1.0.36-android.apk',
          'browser_download_url': 'https://example.test/release.apk',
        },
        {
          'name': 'SHA256SUMS.txt',
          'browser_download_url': 'https://example.test/SHA256SUMS.txt',
        },
      ],
    });

    expect(release.version, '1.0.36');
    expect(release.apkFilename, 'PocketLLM-Lite-v1.0.36-android.apk');
    expect(release.apkDownloadUrl, 'https://example.test/release.apk');
    expect(
      release.checksumDownloadUrl,
      'https://example.test/SHA256SUMS.txt',
    );
    expect(release.apkSha256, isNull);
    expect(release.isNewerThan('1.0.35'), isTrue);
    expect(release.isNewerThan('1.0.36'), isFalse);
  });

  test('direct installation fails closed without a valid SHA-256', () async {
    final stream = UpdateService().downloadAndInstallUpdate(
      'https://example.test/release.apk',
      sha256: null,
    );

    await expectLater(
      stream,
      emitsError(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('no verified APK SHA-256'),
        ),
      ),
    );
  });
}
