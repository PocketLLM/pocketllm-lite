import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ota_update/ota_update.dart';
import 'package:pocketllm_lite/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([http.Client, OtaUpdateWrapper])
import 'update_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService', () {
    late UpdateService updateService;
    late MockClient mockClient;
    late MockOtaUpdateWrapper mockOtaUpdate;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockClient();
      mockOtaUpdate = MockOtaUpdateWrapper();
      updateService = UpdateService();
      updateService.client = mockClient;
      updateService.otaUpdate = mockOtaUpdate;
    });

    test('AppRelease.fromJson parses checksumUrl and apkFilename', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': DateTime.now().toIso8601String(),
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'http://example.com/app-release.apk',
          },
          {
            'name': 'checksums.txt',
            'browser_download_url': 'http://example.com/checksums.txt',
          }
        ]
      };

      final release = AppRelease.fromJson(json);
      expect(release.apkDownloadUrl, 'http://example.com/app-release.apk');
      expect(release.apkFilename, 'app-release.apk');
      expect(release.checksumUrl, 'http://example.com/checksums.txt');
    });

    test('downloadAndInstallUpdate yields error on checksum failure', () async {
      final release = AppRelease(
        tagName: 'v1.0.0',
        version: '1.0.0',
        name: 'Release 1.0.0',
        body: 'Notes',
        publishedAt: DateTime.now(),
        apkDownloadUrl: 'http://example.com/app.apk',
        apkFilename: 'app.apk',
        checksumUrl: 'http://example.com/checksums.txt',
      );

      // Mock 404
      when(mockClient.get(Uri.parse('http://example.com/checksums.txt')))
          .thenAnswer((_) async => http.Response('Not Found', 404));

      final stream = updateService.downloadAndInstallUpdate(release);

      final events = await stream.toList();

      // Should contain DOWNLOADING "0" then CHECKSUM_ERROR
      expect(events.length, 2);
      expect(events[0].status, OtaStatus.DOWNLOADING);
      expect(events[1].status, OtaStatus.CHECKSUM_ERROR);
      expect(events[1].value, contains('Failed to verify update integrity'));
    });

    test('downloadAndInstallUpdate verifies checksum successfully before downloading', () async {
       final release = AppRelease(
        tagName: 'v1.0.0',
        version: '1.0.0',
        name: 'Release 1.0.0',
        body: 'Notes',
        publishedAt: DateTime.now(),
        apkDownloadUrl: 'http://example.com/app.apk',
        apkFilename: 'app.apk',
        checksumUrl: 'http://example.com/checksums.txt',
      );

      // Mock checksum success
      when(mockClient.get(Uri.parse('http://example.com/checksums.txt')))
          .thenAnswer((_) async => http.Response(
            'abc123hash  app.apk\ndef456hash  other.apk',
            200,
          ));

      // Mock OTA update success
      when(mockOtaUpdate.execute(
        any,
        destinationFilename: anyNamed('destinationFilename'),
        sha256checksum: anyNamed('sha256checksum')
      )).thenAnswer((_) => Stream.value(OtaEvent(OtaStatus.INSTALLATION_DONE, '100')));

       final stream = updateService.downloadAndInstallUpdate(release);

       final events = await stream.toList();

       expect(events.length, 2);
       // Custom "Verifying" or "Downloading 0%" event
       expect(events[0].status, OtaStatus.DOWNLOADING);
       expect(events[0].value, '0');
       // OTA event
       expect(events[1].status, OtaStatus.INSTALLATION_DONE);

       verify(mockClient.get(Uri.parse('http://example.com/checksums.txt'))).called(1);
       verify(mockOtaUpdate.execute(
          'http://example.com/app.apk',
          destinationFilename: 'pocketllm_lite_update.apk',
          sha256checksum: 'abc123hash'
       )).called(1);
    });
  });
}
