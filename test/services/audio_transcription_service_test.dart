import 'dart:io';

import 'package:cactus/cactus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/audio_transcription_service.dart';

class _FakeTranscriber implements AudioTranscriber {
  String? receivedPath;

  @override
  Future<CactusTranscriptionResult> transcribe(
    String filePath, {
    String language = 'auto',
  }) async {
    receivedPath = filePath;
    return CactusTranscriptionResult(
      success: true,
      text: 'Words produced from the selected fixture.',
      totalTimeMs: 42,
    );
  }
}

void main() {
  test('passes the real selected file to the ASR backend without invented data',
      () async {
    final directory = await Directory.systemTemp.createTemp('pocketllm_audio_');
    addTearDown(() => directory.delete(recursive: true));
    final fixture =
        File('${directory.path}${Platform.pathSeparator}sample.wav');
    await fixture.writeAsBytes([0x52, 0x49, 0x46, 0x46]);
    final backend = _FakeTranscriber();

    final result = await AudioTranscriptionService(transcriber: backend)
        .transcribeAudioFile(filePath: fixture.path, fileName: 'sample.wav');

    expect(backend.receivedPath, fixture.path);
    expect(result.text, 'Words produced from the selected fixture.');
    expect(result.exportToMarkdown(), isNot(contains('Speaker 1')));
    expect(result.exportToSrt(), isEmpty,
        reason: 'Cactus 1.3 does not return verified segment timestamps.');
  });

  test('rejects missing input before invoking ASR', () async {
    final backend = _FakeTranscriber();
    expect(
      () => AudioTranscriptionService(transcriber: backend).transcribeAudioFile(
          filePath: 'missing.wav', fileName: 'missing.wav'),
      throwsA(isA<AudioTranscriptionError>()),
    );
    expect(backend.receivedPath, isNull);
  });
}
