import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:waveform_flutter/waveform_flutter.dart';

class TtsNotifier extends Notifier<String?> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  String? build() {
    _initTts();
    ref.onDispose(() {
      _flutterTts.stop();
    });
    return null;
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        state = null;
      });

      _flutterTts.setCancelHandler(() {
        state = null;
      });

      _flutterTts.setErrorHandler((msg) {
        state = null;
      });
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> speak(String text, String messageId) async {
    if (state == messageId) {
      await stop();
      return;
    }

    await stop();
    state = messageId;
    // Strip markdown formatting if any to read it cleanly
    final cleanText = text.replaceAll(RegExp(r'[\*\#\`\-\_\>\+]'), '');
    await _flutterTts.speak(cleanText);
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    state = null;
  }
}

final ttsProvider = NotifierProvider<TtsNotifier, String?>(TtsNotifier.new);

class SttState {
  final bool isListening;
  final String lastWords;
  final bool isAvailable;
  final Stream<Amplitude>? amplitudeStream;

  SttState({
    this.isListening = false,
    this.lastWords = '',
    this.isAvailable = false,
    this.amplitudeStream,
  });

  SttState copyWith({
    bool? isListening,
    String? lastWords,
    bool? isAvailable,
    Stream<Amplitude>? amplitudeStream,
  }) {
    return SttState(
      isListening: isListening ?? this.isListening,
      lastWords: lastWords ?? this.lastWords,
      isAvailable: isAvailable ?? this.isAvailable,
      amplitudeStream: amplitudeStream ?? this.amplitudeStream,
    );
  }
}

class SttNotifier extends Notifier<SttState> {
  final SpeechToText _speechToText = SpeechToText();
  StreamController<Amplitude>? _amplitudeController;

  @override
  SttState build() {
    _initSpeech();
    ref.onDispose(() {
      _amplitudeController?.close();
    });
    return SttState();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (val) {
          state = state.copyWith(isListening: false);
          _amplitudeController?.close();
          _amplitudeController = null;
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            state = state.copyWith(isListening: false);
            _amplitudeController?.close();
            _amplitudeController = null;
          }
        },
      );
      state = state.copyWith(isAvailable: available);
    } catch (_) {
      state = state.copyWith(isAvailable: false);
    }
  }

  Future<void> startListening(void Function(String) onResult) async {
    if (state.isListening) return;

    if (!state.isAvailable) {
      await _initSpeech();
      if (!state.isAvailable) return;
    }

    await _amplitudeController?.close();
    _amplitudeController = StreamController<Amplitude>.broadcast();

    state = state.copyWith(
      isListening: true,
      lastWords: '',
      amplitudeStream: _amplitudeController!.stream,
    );

    await _speechToText.listen(
      onResult: (result) {
        state = state.copyWith(lastWords: result.recognizedWords);
        onResult(result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        // level is typically in dB, normalize it for waveform_flutter
        // SpeechToText sound levels are often 0-10 or -10 to 10 depending on platform
        // We'll normalize to 0-100 range
        final normalized = ((level + 2) * 20).clamp(0.0, 100.0);
        _amplitudeController?.add(Amplitude(current: normalized, max: 100));
      },
    );
  }

  Future<void> stopListening() async {
    if (!state.isListening) return;
    await _speechToText.stop();
    await _amplitudeController?.close();
    _amplitudeController = null;
    state = state.copyWith(isListening: false, amplitudeStream: null);
  }
}

final sttProvider = NotifierProvider<SttNotifier, SttState>(SttNotifier.new);
