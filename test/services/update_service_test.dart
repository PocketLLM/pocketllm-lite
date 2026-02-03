import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/services/update_service.dart';

void main() {
  group('AppRelease', () {
    test('fromJson parses standard APK release correctly', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Release 1.0.0',
        'body': 'Notes',
        'published_at': '2023-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://example.com/app.apk'
          }
        ]
      };

      final release = AppRelease.fromJson(json);
      expect(release.version, '1.0.0');
      expect(release.apkDownloadUrl, 'https://example.com/app.apk');
      expect(release.checksumUrl, isNull);
    });

    test('fromJson parses .sha256 correctly', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2023-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app.apk.sha256',
            'browser_download_url': 'https://example.com/sha'
          }
        ]
      };
      final release = AppRelease.fromJson(json);
      expect(release.checksumUrl, 'https://example.com/sha');
    });

    test('fromJson parses checksums.txt correctly', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2023-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'checksums.txt',
            'browser_download_url': 'https://example.com/checksums'
          }
        ]
      };
      final release = AppRelease.fromJson(json);
      expect(release.checksumUrl, 'https://example.com/checksums');
    });
  });

  group('UpdateService Checksum', () {
    late UpdateService service;

    setUp(() {
      service = UpdateService();
    });

    test('fetchChecksum parses raw hash', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            200);
      });
      service.client = mockClient;

      final checksum = await service.fetchChecksum('http://test.com/sha');
      expect(checksum,
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('fetchChecksum parses hash filename format', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  app.apk\n',
            200);
      });
      service.client = mockClient;

      final checksum = await service.fetchChecksum('http://test.com/sha');
      expect(checksum,
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('fetchChecksum handles invalid format', () async {
      final mockClient = MockClient((request) async {
        return http.Response('invalid content', 200);
      });
      service.client = mockClient;

      final checksum = await service.fetchChecksum('http://test.com/sha');
      expect(checksum, isNull);
    });

    test('fetchChecksum handles network error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      service.client = mockClient;

      final checksum = await service.fetchChecksum('http://test.com/sha');
      expect(checksum, isNull);
    });
  });
}
