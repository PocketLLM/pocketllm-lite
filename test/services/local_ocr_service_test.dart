import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/local_ocr_service.dart';

class _ReadingOcrPlatform implements OcrPlatform {
  List<int>? receivedBytes;

  @override
  Future<Map<String, dynamic>> recognize(String imagePath) async {
    receivedBytes = await File(imagePath).readAsBytes();
    return {'text': 'Detected fixture text'};
  }
}

void main() {
  test('processes the supplied image bytes and deletes the temporary input',
      () async {
    final directory = await Directory.systemTemp.createTemp('pocketllm_ocr_');
    addTearDown(() => directory.delete(recursive: true));
    final platform = _ReadingOcrPlatform();
    final service = LocalOcrService(
      platform: platform,
      isSupported: () => true,
      temporaryDirectory: () async => directory,
    );

    final result = await service.processImageBytes(
      Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(platform.receivedBytes, [1, 2, 3, 4]);
    expect(result.rawText, 'Detected fixture text');
    expect(directory.listSync(), isEmpty);
  });

  test('never returns canned success for empty input', () {
    expect(
      () => LocalOcrService().processImageBytes(Uint8List(0)),
      throwsA(isA<OcrError>()),
    );
  });
}
