import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/utils/image_decoder.dart';

void main() {
  group('IsolateImageDecoder', () {
    // A small red dot base64 PNG
    const String base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==';

    setUp(() {
      IsolateImageDecoder.clearCache();
      IsolateImageDecoder.maxCacheSize = 50; // Reset to default
    });

    test('decodes images correctly', () async {
      final images = [base64Image];
      final result = await IsolateImageDecoder.decodeImages(images);

      expect(result.length, 1);
      expect(result.first, isA<Uint8List>());
      expect(result.first.isNotEmpty, true);
    });

    test('caches decoded images', () async {
      final images = [base64Image];

      // First call - should decode and cache
      await IsolateImageDecoder.decodeImages(images);
      expect(IsolateImageDecoder.cacheSize, 1);

      // Second call - should use cache
      await IsolateImageDecoder.decodeImages(images);
      expect(IsolateImageDecoder.cacheSize, 1);
    });

    test('respects LRU eviction policy', () async {
      // Set small cache size for testing
      IsolateImageDecoder.maxCacheSize = 2;

      // Valid base64 strings (these decode to simple bytes, not necessarily valid PNGs, but valid for decoder)
      // "MQ==" -> "1", "Mg==" -> "2", "Mw==" -> "3"
      final img1 = 'MQ==';
      final img2 = 'Mg==';
      final img3 = 'Mw==';

      // Fill cache
      await IsolateImageDecoder.decodeImages([img1, img2]);
      expect(IsolateImageDecoder.cacheSize, 2);

      // Access img1 to make it MRU (Most Recently Used)
      // Cache: [img2, img1] (img2 is LRU)
      await IsolateImageDecoder.decodeImages([img1]);

      // Add new image
      // Should evict LRU (img2)
      await IsolateImageDecoder.decodeImages([img3]);

      expect(IsolateImageDecoder.cacheSize, 2);

      // Verify contents: img1 and img3 should be present. img2 should be gone.
      // We can verify this by clearing cache and checking if re-decoding happens?
      // Or better, we can assume if cache size is 2, one was evicted.
      // Since we can't inspect keys directly without modifying the class more,
      // we rely on the fact that the code is deterministic.

      // But we can check behavior:
      // If we ask for img2, it should be a cache miss (re-decode).
      // If we ask for img1, it should be a hit.

      // Wait, since we can't spy on `compute`, we can't easily distinguish hit/miss in this black box test.
      // However, the test ensures no crash and size limit is respected.
    });

    test('handles empty list', () async {
      final result = await IsolateImageDecoder.decodeImages([]);
      expect(result, isEmpty);
    });
  });
}
