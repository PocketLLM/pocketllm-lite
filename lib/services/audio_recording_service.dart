import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum AudioRecordingPhase { idle, recording, paused, ready }

class AudioRecordingState {
  final AudioRecordingPhase phase;
  final Duration elapsed;
  final double amplitudeDb;
  final String? filePath;
  final bool isPlaying;
  final String? error;

  const AudioRecordingState({
    this.phase = AudioRecordingPhase.idle,
    this.elapsed = Duration.zero,
    this.amplitudeDb = -160,
    this.filePath,
    this.isPlaying = false,
    this.error,
  });

  AudioRecordingState copyWith({
    AudioRecordingPhase? phase,
    Duration? elapsed,
    double? amplitudeDb,
    String? filePath,
    bool? isPlaying,
    String? error,
    bool clearError = false,
  }) =>
      AudioRecordingState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        amplitudeDb: amplitudeDb ?? this.amplitudeDb,
        filePath: filePath ?? this.filePath,
        isPlaying: isPlaying ?? this.isPlaying,
        error: clearError ? null : error ?? this.error,
      );
}

class AudioRecordingService {
  AudioRecordingService({AudioRecorder? recorder, AudioPlayer? player})
      : _recorder = recorder ?? AudioRecorder(),
        _player = player ?? AudioPlayer();

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  final ValueNotifier<AudioRecordingState> state =
      ValueNotifier(const AudioRecordingState());
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _timer;
  DateTime? _runningSince;
  Duration _accumulated = Duration.zero;

  Future<bool> hasPermission({bool request = false}) =>
      _recorder.hasPermission(request: request);

  Future<void> start() async {
    if (state.value.phase == AudioRecordingPhase.recording ||
        state.value.phase == AudioRecordingPhase.paused) {
      throw StateError('A recording is already active.');
    }
    if (!await _recorder.hasPermission()) {
      state.value = state.value.copyWith(
        error:
            'Microphone permission is required. Enable it in system settings.',
      );
      throw StateError(state.value.error!);
    }
    final directory = await _recordingsDirectory();
    final destination = path.join(
      directory.path,
      'recording-${DateTime.now().toUtc().millisecondsSinceEpoch}.wav',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: destination,
    );
    _accumulated = Duration.zero;
    _runningSince = DateTime.now();
    state.value = AudioRecordingState(
      phase: AudioRecordingPhase.recording,
      filePath: destination,
    );
    _startTimer();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((value) {
      state.value = state.value.copyWith(amplitudeDb: value.current);
    });
  }

  Future<void> pause() async {
    if (state.value.phase != AudioRecordingPhase.recording) return;
    await _recorder.pause();
    _captureElapsed();
    _timer?.cancel();
    state.value = state.value.copyWith(
      phase: AudioRecordingPhase.paused,
      elapsed: _accumulated,
    );
  }

  Future<void> resume() async {
    if (state.value.phase != AudioRecordingPhase.paused) return;
    await _recorder.resume();
    _runningSince = DateTime.now();
    state.value = state.value.copyWith(phase: AudioRecordingPhase.recording);
    _startTimer();
  }

  Future<String> stop() async {
    final stoppedPath = await _recorder.stop();
    _captureElapsed();
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    final savedPath = stoppedPath ?? state.value.filePath;
    if (savedPath == null || !await File(savedPath).exists()) {
      state.value = state.value.copyWith(
        phase: AudioRecordingPhase.idle,
        error: 'The recorder stopped without producing an audio file.',
      );
      throw StateError(state.value.error!);
    }
    state.value = state.value.copyWith(
      phase: AudioRecordingPhase.ready,
      elapsed: _accumulated,
      filePath: savedPath,
      amplitudeDb: -160,
    );
    return savedPath;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    final existingPath = state.value.filePath;
    if (existingPath != null) {
      final file = File(existingPath);
      if (await file.exists()) await file.delete();
    }
    _accumulated = Duration.zero;
    state.value = const AudioRecordingState();
  }

  Future<void> useFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('Choose a non-empty audio file.');
    }
    await stopPlayback();
    state.value = AudioRecordingState(
      phase: AudioRecordingPhase.ready,
      filePath: file.path,
    );
  }

  Future<String> rename(String name) async {
    final current = state.value.filePath;
    if (current == null) throw StateError('No recording is ready to rename.');
    final source = File(current);
    final sanitized = name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._ -]+'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    if (sanitized.isEmpty) throw ArgumentError('Enter a valid recording name.');
    final extension = path.extension(source.path).isEmpty
        ? '.wav'
        : path.extension(source.path);
    final base = path.basenameWithoutExtension(sanitized);
    final destination = path.join(source.parent.path, '$base$extension');
    if (destination == source.path) return destination;
    if (await File(destination).exists()) {
      throw StateError('A recording with that name already exists.');
    }
    final renamed = await source.rename(destination);
    state.value = state.value.copyWith(filePath: renamed.path);
    return renamed.path;
  }

  Future<void> togglePlayback() async {
    final filePath = state.value.filePath;
    if (filePath == null) return;
    if (_player.playing) {
      await _player.pause();
      state.value = state.value.copyWith(isPlaying: false);
      return;
    }
    if (_player.audioSource == null) {
      await _player.setFilePath(filePath);
    }
    _playerSubscription ??= _player.playerStateStream.listen((playerState) {
      final playing = playerState.playing &&
          playerState.processingState != ProcessingState.completed;
      state.value = state.value.copyWith(isPlaying: playing);
      if (playerState.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
      }
    });
    await _player.play();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    state.value = state.value.copyWith(isPlaying: false);
  }

  Future<Directory> _recordingsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'audio'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  void _captureElapsed() {
    final started = _runningSince;
    if (started != null) _accumulated += DateTime.now().difference(started);
    _runningSince = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final started = _runningSince;
      state.value = state.value.copyWith(
        elapsed: _accumulated +
            (started == null
                ? Duration.zero
                : DateTime.now().difference(started)),
      );
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    await _playerSubscription?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    state.dispose();
  }
}
