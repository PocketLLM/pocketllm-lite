import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Decodes base64 strings to Uint8List in a separate isolate to avoid blocking the UI thread.
class IsolateImageDecoder {
  /// Decodes a list of base64 strings into a list of Uint8List.
  ///
  /// This operation runs in a separate isolate (using `compute`).
  static Future<List<Uint8List>> decodeImages(List<String> base64Images) async {
    if (base64Images.isEmpty) return [];

    // For a single image or small payload, the overhead of compute might be negligible,
    // but for consistent performance with potentially large images, we offload it.
    return compute(_decodeImagesInternal, base64Images);
  }

  /// Internal function that runs in the isolate.
  static List<Uint8List> _decodeImagesInternal(List<String> images) {
    return images.map((str) => base64Decode(str)).toList();
  }
}
