import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/services/update_service.dart';

// Generate mock client
@GenerateMocks([http.Client])
import 'update_service_checksum_test.mocks.dart';

void main() {
  group('AppRelease Checksum Parsing', () {
    test('extracts apk and checksum url correctly', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': DateTime.now().toIso8601String(),
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app.apk'
          },
          {
            'name': 'checksums.txt',
            'browser_download_url': 'http://example.com/checksums.txt'
          }
        ]
      };

      final release = AppRelease.fromJson(json);
      expect(release.apkDownloadUrl, 'http://example.com/app.apk');
      expect(release.apkFilename, 'app-release.apk');
      expect(release.checksumUrl, 'http://example.com/checksums.txt');
    });

    test('extracts apk and specific sha256 file', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': DateTime.now().toIso8601String(),
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

    test('ignores irrelevant files', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': DateTime.now().toIso8601String(),
        'assets': [
          {
            'name': 'readme.md',
            'browser_download_url': 'http://example.com/readme.md'
          }
        ]
      };

      final release = AppRelease.fromJson(json);
      expect(release.apkDownloadUrl, null);
      expect(release.checksumUrl, null);
    });
  });

  group('UpdateService Checksum Extraction', () {
    late UpdateService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = UpdateService();
      service.setClient(mockClient);
    });

    test('extracts simple hash', () {
      const hash =
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';
      final result = service.extractChecksum(hash, 'app.apk');
      expect(result, hash);
    });

    test('extracts hash with filename (standard)', () {
      const hash =
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';
      const content = '$hash  app.apk\n';
      final result = service.extractChecksum(content, 'app.apk');
      expect(result, hash);
    });

    test('extracts hash with *filename (binary)', () {
      const hash =
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';
      const content = '$hash *app.apk\n';
      final result = service.extractChecksum(content, 'app.apk');
      expect(result, hash);
    });

    test('extracts correct hash from list', () {
      const hash1 =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const hash2 =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const content = '''
$hash1  other.apk
$hash2  app.apk
''';
      final result = service.extractChecksum(content, 'app.apk');
      expect(result, hash2);
    });

    test('returns null if filename not found', () {
      const hash =
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';
      const content = '$hash  other.apk\n';
      final result = service.extractChecksum(content, 'app.apk');
      expect(result, null);
    });

    test('returns null if hash is invalid', () {
      const hash = 'invalid-hash';
      const content = '$hash  app.apk\n';
      final result = service.extractChecksum(content, 'app.apk');
      expect(result, null);
    });

    test('fetchChecksum returns body on 200', () async {
      when(
        mockClient.get(Uri.parse('http://example.com/checksum')),
      ).thenAnswer((_) async => http.Response('content', 200));

      final result = await service.fetchChecksum('http://example.com/checksum');
      expect(result, 'content');
    });

    test('fetchChecksum returns null on 404', () async {
      when(
        mockClient.get(Uri.parse('http://example.com/checksum')),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await service.fetchChecksum('http://example.com/checksum');
      expect(result, null);
    });
  });
}
