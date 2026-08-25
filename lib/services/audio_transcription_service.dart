import 'dart:io';

import 'package:cactus/cactus.dart' as cactus;
// Pinned Cactus 1.3.0 local adapter. The public STT wrapper can download from
// Supabase internally, which cannot satisfy PocketLLM's central network policy.
// ignore: implementation_imports
import 'package:cactus/src/services/context.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  @override
  Future<cactus.CactusTranscriptionResult> transcribe(String filePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final modelDirectory =
        Directory(path.join(documents.path, 'models', modelId));
    if (!await modelDirectory.exists()) {
      throw const AudioTranscriptionError(
        'The offline Whisper model is not installed. Automatic Cactus '
        'downloads are disabled because that SDK path bypasses the network '
        'audit gateway.',
      );
    }
    final initialized = await CactusContext.initContext(
      modelDirectory.path,
      2048,
    );
    final handle = initialized.$1;
    if (handle == null) {
      throw AudioTranscriptionError(
        'The installed Whisper model could not be initialized: '
        '${initialized.$2}',
      );
    }
    try {
      return await CactusContext.transcribe(
        handle,
        cactus.CactusSTT.whisperPrompt,
        audioFilePath: filePath,
        params: cactus.CactusTranscriptionParams(maxTokens: 2048),
      );
    } finally {
      CactusContext.freeContext(handle);
    }
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
