import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketllm_lite/services/update_service.dart';

class MockClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  group('UpdateService Tests', () {
    late UpdateService updateService;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      updateService = UpdateService();
      PackageInfo.setMockInitialValues(
        appName: 'PocketLLM',
        packageName: 'com.example.pocketllm',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    test('AppRelease parsing - finds checksums', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Release',
        'body': 'Notes',
        'published_at': '2025-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url': 'http://example.com/app.apk'
          },
          {
            'name': 'checksums.txt',
            'browser_download_url': 'http://example.com/checksums.txt'
          }
        ]
      };

      final release = AppRelease.fromJson(json);
      expect(release.apkFilename, 'app.apk');
      expect(release.apkDownloadUrl, 'http://example.com/app.apk');
      expect(release.checksumUrl, 'http://example.com/checksums.txt');
    });

    test('AppRelease parsing - finds specific sha256 file', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Release',
        'body': 'Notes',
        'published_at': '2025-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app.apk',
            'browser_download_url': 'http://example.com/app.apk'
          },
          {
            'name': 'app.apk.sha256',
            'browser_download_url': 'http://example.com/app.apk.sha256'
          }
        ]
      };

      final release = AppRelease.fromJson(json);
      expect(release.apkFilename, 'app.apk');
      expect(release.checksumUrl, 'http://example.com/app.apk.sha256');
    });

    test('checkForUpdates uses custom client', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://api.github.com/repos/PocketLLM/pocketllm-lite/releases/latest') {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
               'tag_name': 'v9.9.9', // Newer than 1.0.0
               'name': 'New Version',
               'body': 'New stuff',
               'published_at': DateTime.now().toIso8601String(),
               'assets': []
            }))),
            200,
          );
        }
        return http.StreamedResponse(Stream.empty(), 404);
      });

      updateService.client = mockClient;
      final result = await updateService.checkForUpdates(force: true);

      expect(result.updateAvailable, true);
      expect(result.release?.tagName, 'v9.9.9');
    });
  });
}
