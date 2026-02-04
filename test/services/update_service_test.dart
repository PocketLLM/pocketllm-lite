import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/update_service.dart';

@GenerateMocks([http.Client])
import 'update_service_test.mocks.dart';

void main() {
  group('AppRelease Checksum Parsing', () {
    test('parses .sha256 file URL', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2023-01-01T00:00:00Z',
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
      expect(release.checksumUrl, 'http://example.com/app.apk.sha256');
    });

    test('parses checksums.txt file URL', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2023-01-01T00:00:00Z',
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
      expect(release.checksumUrl, 'http://example.com/checksums.txt');
    });
  });

  group('UpdateService Checksum Fetching', () {
    late UpdateService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = UpdateService();
      service.client = mockClient;
    });

    test('fetchChecksum parses single line hash', () async {
      final hash = 'a' * 64;
      when(mockClient.get(Uri.parse('http://example.com/hash')))
          .thenAnswer((_) async => http.Response(hash, 200));

      final result = await service.fetchChecksum('http://example.com/hash');
      expect(result, hash);
    });

    test('fetchChecksum parses "hash filename" format', () async {
      final hash = 'b' * 64;
      final content = '$hash  app-release.apk\n';
      when(mockClient.get(Uri.parse('http://example.com/checksums.txt')))
          .thenAnswer((_) async => http.Response(content, 200));

      final result = await service.fetchChecksum('http://example.com/checksums.txt');
      expect(result, hash);
    });

    test('fetchChecksum parses "SHA256 (filename) = hash" format', () async {
       final hash = 'c' * 64;
       final content = 'SHA256 (app.apk) = $hash\n';
       when(mockClient.get(Uri.parse('http://example.com/bsd_checksum')))
           .thenAnswer((_) async => http.Response(content, 200));

       final result = await service.fetchChecksum('http://example.com/bsd_checksum');
       expect(result, hash);
    });

    test('fetchChecksum finds correct hash for .apk in multiline file', () async {
      final hash1 = '1' * 64; // other file
      final hash2 = '2' * 64; // apk file
      final content = '''
$hash1  other-file.zip
$hash2  pocketllm_lite.apk
''';
      when(mockClient.get(Uri.parse('http://example.com/checksums.txt')))
          .thenAnswer((_) async => http.Response(content, 200));

      final result = await service.fetchChecksum('http://example.com/checksums.txt');
      expect(result, hash2);
    });

    test('fetchChecksum returns null on error', () async {
      when(mockClient.get(any))
          .thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await service.fetchChecksum('http://example.com/404');
      expect(result, null);
    });
  });
}
