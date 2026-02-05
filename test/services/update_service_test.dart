import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PocketLLM',
      packageName: 'com.pocketllm.lite',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  group('AppRelease Tests', () {
    test('fromJson parses standard APK asset', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': 'Release 1.0.1',
        'body': 'Notes',
        'published_at': '2023-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app-release.apk',
          },
        ],
      };
      final release = AppRelease.fromJson(json);
      expect(release.version, '1.0.1');
      expect(release.apkDownloadUrl, 'http://example.com/app-release.apk');
      expect(release.apkFilename, 'app-release.apk');
      expect(release.checksumUrl, null);
    });

    test('fromJson parses checksum asset', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': 'Release 1.0.1',
        'body': 'Notes',
        'published_at': '2023-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app-release.apk',
          },
          {
            'name': 'app-release.apk.sha256',
            'browser_download_url': 'http://example.com/app-release.apk.sha256',
          },
        ],
      };
      final release = AppRelease.fromJson(json);
      expect(release.checksumUrl, 'http://example.com/app-release.apk.sha256');
    });

    test('fromJson parses checksums.txt', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': 'Release 1.0.1',
        'body': 'Notes',
        'published_at': '2023-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app-release.apk',
          },
          {
            'name': 'checksums.txt',
            'browser_download_url': 'http://example.com/checksums.txt',
          },
        ],
      };
      final release = AppRelease.fromJson(json);
      expect(release.checksumUrl, 'http://example.com/checksums.txt');
    });
  });

  group('UpdateService Tests', () {
    test('fetchChecksum parses simple hash file', () async {
      final mockClient = MockClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('a1b2c3d4e5f6  app-release.apk\n')),
          200,
        );
      });

      final service = UpdateService.test(client: mockClient);
      final checksum = await service.fetchChecksum(
        'http://example.com/hash',
        'app-release.apk',
      );
      expect(checksum, 'a1b2c3d4e5f6');
    });

    test('fetchChecksum parses checksums.txt with filename', () async {
      final mockClient = MockClient((request) async {
        final content = '''
a1b2c3d4e5f6  other.apk
f0e1d2c3b4a5  target.apk
        ''';
        return http.StreamedResponse(Stream.value(utf8.encode(content)), 200);
      });

      final service = UpdateService.test(client: mockClient);
      final checksum = await service.fetchChecksum(
        'http://example.com/checksums.txt',
        'target.apk',
      );
      expect(checksum, 'f0e1d2c3b4a5');
    });

    test('checkForUpdates uses mocked client', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('releases/latest')) {
          final body = jsonEncode({
            'tag_name': 'v2.0.0',
            'name': 'v2.0.0',
            'body': 'Fixes',
            'published_at': DateTime.now().toIso8601String(),
            'assets': [],
          });
          return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
        }
        return http.StreamedResponse(Stream.empty(), 404);
      });

      final service = UpdateService.test(client: mockClient);

      final result = await service.checkForUpdates(force: true);
      expect(result.updateAvailable, true);
      expect(result.release?.version, '2.0.0');
    });
  });
}
