import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Decodes base64 strings to Uint8List in a separate isolate to avoid blocking the UI thread.
/// Includes an in-memory LRU cache to prevent repeated decoding of the same images (e.g. during scrolling).
class IsolateImageDecoder {
  static int _maxCacheSize = 50;

  @visibleForTesting
  static set maxCacheSize(int value) => _maxCacheSize = value;

  // Dart's Map is a LinkedHashMap by default, preserving insertion order.
  static final Map<String, Uint8List> _cache = {};

  /// Decodes a list of base64 strings into a list of Uint8List.
  ///
  /// This operation runs in a separate isolate (using `compute`) for new images,
  /// but retrieves from cache synchronously if available.
  static Future<List<Uint8List>> decodeImages(List<String> base64Images) async {
    if (base64Images.isEmpty) return [];

    final List<Uint8List> results = List<Uint8List>.filled(
      base64Images.length,
      Uint8List(0),
    );
    final List<String> toDecode = [];
    final List<int> toDecodeIndices = [];

    for (int i = 0; i < base64Images.length; i++) {
      final img = base64Images[i];
      if (_cache.containsKey(img)) {
        // Cache Hit: Re-insert to move to the end (Most Recently Used position)
        final data = _cache.remove(img)!;
        _cache[img] = data;
        results[i] = data;
      } else {
        toDecode.add(img);
        toDecodeIndices.add(i);
      }
    }

    if (toDecode.isNotEmpty) {
      // For a single image or small payload, the overhead of compute might be negligible,
      // but for consistent performance with potentially large images, we offload it.
      final decoded = await compute(_decodeImagesInternal, toDecode);

      for (int i = 0; i < decoded.length; i++) {
        final key = toDecode[i];
        final value = decoded[i];

        // Add to cache
        // If key already exists (unlikely given logic above), it updates and moves to end.
        // If new, checks size.
        if (_cache.length >= _maxCacheSize && !_cache.containsKey(key)) {
          _cache.remove(
            _cache.keys.first,
          ); // Remove Least Recently Used (first key)
        }
        _cache[key] = value;

        results[toDecodeIndices[i]] = value;
      }
    }

    return results;
  }

  /// Internal function that runs in the isolate.
  static List<Uint8List> _decodeImagesInternal(List<String> images) {
    return images.map((str) => base64Decode(str)).toList();
  }

  /// Clears the image cache. Useful for testing or memory management.
  @visibleForTesting
  static void clearCache() {
    _cache.clear();
  }

  /// Returns the current cache size.
  @visibleForTesting
  static int get cacheSize => _cache.length;
}
