import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/utils/image_decoder.dart';

void main() {
  group('IsolateImageDecoder Memory Optimization', () {
    // Two different base64 strings
    final img1 = base64Encode(utf8.encode('Image1Content'));
    final img2 = base64Encode(utf8.encode('Image2Content'));

    setUp(() {
      IsolateImageDecoder.clearCache();
      IsolateImageDecoder.maxCacheSize = 50;
    });

    test('Treats different strings with different hashCodes as different cache entries', () async {
      // Decode img1
      await IsolateImageDecoder.decodeImages([img1]);
      expect(IsolateImageDecoder.cacheSize, 1);

      // Decode img2
      await IsolateImageDecoder.decodeImages([img2]);
      expect(IsolateImageDecoder.cacheSize, 2);

      // Decode img1 again - should hit cache (size remains 2)
      await IsolateImageDecoder.decodeImages([img1]);
      expect(IsolateImageDecoder.cacheSize, 2);
    });

    test('Handles same string (same hash) correctly', () async {
       // Since we use hashCode, same string = same hash = same cache entry.
       await IsolateImageDecoder.decodeImages([img1]);
       await IsolateImageDecoder.decodeImages([img1]);
       expect(IsolateImageDecoder.cacheSize, 1);
    });
  });
}
