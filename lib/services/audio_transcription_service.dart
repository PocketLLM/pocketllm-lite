import 'dart:io';

import 'package:cactus/cactus.dart' as cactus;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'network_policy_service.dart';

class AudioTranscriptionError implements Exception {
  final String message;
  const AudioTranscriptionError(this.message);

  @override
  String toString() => message;
}

class TranscriptSegment {
  final int startTimeMs;
  final int endTimeMs;
  final String text;

  const TranscriptSegment({
    required this.startTimeMs,
    required this.endTimeMs,
    required this.text,
  });

  String formatTimestamp() {
    final seconds = (startTimeMs / 1000).floor();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class AudioTranscriptionResult {
  final String id;
  final String fileName;
  final List<TranscriptSegment> segments;
  final DateTime createdAt;
  final double processingTimeMs;

  const AudioTranscriptionResult({
    required this.id,
    required this.fileName,
    required this.segments,
    required this.createdAt,
    required this.processingTimeMs,
  });

  String get text => segments.map((segment) => segment.text).join('\n').trim();

  String exportToMarkdown() => '# Audio Transcript: $fileName\n\n'
      '**Date:** ${createdAt.toUtc().toIso8601String()}\n\n$text\n';

  String exportToSrt() {
    final buffer = StringBuffer();
    var index = 1;
    for (final segment in segments) {
      if (segment.endTimeMs <= segment.startTimeMs) continue;
      buffer
        ..writeln(index++)
        ..writeln('${_formatSrtTime(segment.startTimeMs)} --> '
            '${_formatSrtTime(segment.endTimeMs)}')
        ..writeln(segment.text)
        ..writeln();
    }
    return buffer.toString();
  }

  String _formatSrtTime(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes % 60)}:'
        '${two(duration.inSeconds % 60)},'
        '${(milliseconds % 1000).toString().padLeft(3, '0')}';
  }
}

abstract class AudioTranscriber {
  Future<cactus.CactusTranscriptionResult> transcribe(String filePath);
}

class CactusWhisperTranscriber implements AudioTranscriber {
  static const modelId = 'whisper-tiny';
  final cactus.CactusSTT _stt;

  CactusWhisperTranscriber({cactus.CactusSTT? stt})
      : _stt = stt ?? cactus.CactusSTT();

  @override
  Future<cactus.CactusTranscriptionResult> transcribe(String filePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final modelDirectory =
        Directory(path.join(documents.path, 'models', modelId));
    if (!await modelDirectory.exists()) {
      final policy = NetworkPolicyService().evaluateConnection(
        uri: Uri.parse('https://huggingface.co/Cactus-Compute'),
        purpose: ConnectionPurpose.modelDownload,
        trigger: 'audio_transcription_model_download',
        infoSent: 'Whisper model identifier; no audio or transcript content',
      );
      if (!policy.allowed) {
        throw AudioTranscriptionError(
          policy.reason ?? 'The Whisper model download is blocked.',
        );
      }
      await _stt.downloadModel(model: modelId);
    }
    await _stt.initializeModel(
      params: cactus.CactusInitParams(model: modelId, contextSize: 2048),
    );
    return _stt.transcribe(audioFilePath: filePath);
  }
}

class AudioTranscriptionService {
  final AudioTranscriber _transcriber;

  AudioTranscriptionService({AudioTranscriber? transcriber})
      : _transcriber = transcriber ?? CactusWhisperTranscriber();

  Future<AudioTranscriptionResult> transcribeAudioFile({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists() || await file.length() == 0) {
      throw const AudioTranscriptionError('Select a non-empty audio file.');
    }
    final result = await _transcriber.transcribe(filePath);
    if (!result.success || result.text.trim().isEmpty) {
      throw AudioTranscriptionError(
        result.errorMessage ?? 'No speech could be transcribed from this file.',
      );
    }
    return AudioTranscriptionResult(
      id: 'tx_${DateTime.now().microsecondsSinceEpoch}',
      fileName: fileName,
      segments: [
        TranscriptSegment(
          startTimeMs: 0,
          endTimeMs: 0,
          text: result.text.trim(),
        ),
      ],
      createdAt: DateTime.now(),
      processingTimeMs: result.totalTimeMs,
    );
  }
}
