import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/providers.dart';

/// Provider that checks Ollama connection status
final connectionStatusProvider = FutureProvider<bool>((ref) async {
  final ollama = ref.watch(ollamaServiceProvider);
  return ollama.checkConnection();
});

/// Provider that periodically checks connection status and auto-refreshes
class ConnectionCheckerNotifier extends AsyncNotifier<bool> {
  Timer? _timer;

  @override
  Future<bool> build() async {
    // Initial check
    final ollama = ref.watch(ollamaServiceProvider);
    final isConnected = await ollama.checkConnection();
    
    // Start periodic checking
    _startPeriodicCheck();
    
    ref.onDispose(() {
      _timer?.cancel();
    });
    
    return isConnected;
  }

  void _startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final ollama = ref.read(ollamaServiceProvider);
        final isConnected = await ollama.checkConnection();
        state = AsyncData(isConnected);
      } catch (e) {
        state = const AsyncData(false);
      }
    });
  }

  /// Manual refresh method
  Future<void> refresh() async {
    try {
      state = const AsyncLoading();
      final ollama = ref.read(ollamaServiceProvider);
      final isConnected = await ollama.checkConnection();
      state = AsyncData(isConnected);
    } catch (e) {
      state = const AsyncData(false);
    }
  }
}

/// Provider that automatically checks connection status periodically
final autoConnectionStatusProvider = AsyncNotifierProvider<ConnectionCheckerNotifier, bool>(
  ConnectionCheckerNotifier.new,
);