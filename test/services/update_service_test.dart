import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Mock the OTA Update channel to prevent hang/timeout
  const EventChannel eventChannel = EventChannel('sk.nicstreofficial.ota_update/stream');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'sk.nicstreofficial.ota_update/stream',
      (ByteData? message) async {
         // EventChannel uses binary messenger directly for handshake?
         // Actually EventChannel is implemented via MethodChannel mechanism under the hood for listen/cancel.
         // 'sk.nicstreofficial.ota_update/stream' might be the name.
         // Standard EventChannel uses 'listen' and 'cancel' methods on the channel.
         return null;
      },
    );

    // The proper way to mock EventChannel in tests:
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
           // Send an error immediately so stream.first throws/completes
           events.error(code: 'MOCK_ERROR', message: 'Mock Error');
        },
      ),
    );
  });

  group('AppRelease', () {
    test('fromJson parses APK and checksum assets correctly', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2025-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app.apk',
          },
          {
            'name': 'checksums.txt',
            'browser_download_url': 'http://example.com/checksums.txt',
          },
        ],
      };

      final release = AppRelease.fromJson(json);

      expect(release.apkDownloadUrl, 'http://example.com/app.apk');
      expect(release.apkFilename, 'app-release.apk');
      expect(release.checksumUrl, 'http://example.com/checksums.txt');
    });

    test('fromJson handles missing checksum', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2025-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app.apk',
          },
        ],
      };

      final release = AppRelease.fromJson(json);

      expect(release.checksumUrl, null);
    });

    test('fromJson prioritizes .sha256 extension', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2025-01-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app.apk',
          },
          {
            'name': 'app-release.apk.sha256',
            'browser_download_url': 'http://example.com/sha256',
          },
        ],
      };

      final release = AppRelease.fromJson(json);
      expect(release.checksumUrl, 'http://example.com/sha256');
    });
  });

  group('UpdateService', () {
    test('fetchChecksum extracts valid hash', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == 'http://checksum') {
          return http.Response(
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  app.apk', 200);
        }
        return http.Response('', 404);
      });

      final result = await UpdateService.fetchChecksum(
        client,
        'http://checksum',
        'app.apk',
      );

      expect(
        result,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('fetchChecksum returns null on 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final result = await UpdateService.fetchChecksum(
        client,
        'http://checksum',
        'app.apk',
      );

      expect(result, null);
    });

    test('fetchChecksum handles invalid format', () async {
      final client = MockClient((request) async {
        return http.Response('invalid content', 200);
      });

      final result = await UpdateService.fetchChecksum(
        client,
        'http://checksum',
        'app.apk',
      );

      expect(result, null);
    });

    test('fetchChecksum ignores wrong filename', () async {
      final client = MockClient((request) async {
        return http.Response(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  other.apk',
            200);
      });

      final result = await UpdateService.fetchChecksum(
        client,
        'http://checksum',
        'app.apk',
      );

      expect(result, null);
    });
  });
}
