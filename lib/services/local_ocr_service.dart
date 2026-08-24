import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class OcrError implements Exception {
  final String message;
  const OcrError(this.message);

  @override
  String toString() => message;
}

class OcrExtractionResult {
  final String rawText;
  final double? confidence;

  const OcrExtractionResult({required this.rawText, this.confidence});
}

abstract class OcrPlatform {
  Future<Map<String, dynamic>> recognize(String imagePath);
}

class MethodChannelOcrPlatform implements OcrPlatform {
  static const _channel = MethodChannel('pocketllm_lite/ocr');

  @override
  Future<Map<String, dynamic>> recognize(String imagePath) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      {'path': imagePath},
    );
    return result ?? const {};
  }
}

class LocalOcrService {
  final OcrPlatform _platform;
  final bool Function() _isSupported;
  final Future<Directory> Function() _temporaryDirectory;

  LocalOcrService({
    OcrPlatform? platform,
    bool Function()? isSupported,
    Future<Directory> Function()? temporaryDirectory,
  })  : _platform = platform ?? MethodChannelOcrPlatform(),
        _isSupported = isSupported ?? (() => Platform.isAndroid),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  Future<OcrExtractionResult> processImageBytes(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw const OcrError('The selected image is empty.');
    }
    if (!_isSupported()) {
      throw const OcrError(
        'On-device OCR is currently available on Android only.',
      );
    }
    final temporaryDirectory = await _temporaryDirectory();
    final file = File(path.join(
      temporaryDirectory.path,
      'ocr_${DateTime.now().microsecondsSinceEpoch}.img',
    ));
    try {
      await file.writeAsBytes(imageBytes, flush: true);
      final result = await _platform.recognize(file.path);
      final text = (result['text'] as String? ?? '').trim();
      if (text.isEmpty) {
        throw const OcrError('No text was detected in the selected image.');
      }
      return OcrExtractionResult(
        rawText: text,
        confidence: (result['confidence'] as num?)?.toDouble(),
      );
    } on PlatformException catch (error) {
      throw OcrError(error.message ?? 'On-device OCR failed.');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}
