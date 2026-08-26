import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/models_provider.dart';
import 'package:pocketllm_lite/services/ollama_service.dart';

class _SlowClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return http.StreamedResponse(Stream.empty(), 200);
  }
}

void main() {
  test('Ollama model discovery fails fast when the endpoint never responds',
      () async {
    final container = ProviderContainer(
      overrides: [
        ollamaServiceProvider.overrideWithValue(
          OllamaService(client: _SlowClient()),
        ),
        modelDiscoveryTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
      ],
    );
    addTearDown(container.dispose);
    final result = Completer<Object?>();
    final subscription = container.listen(
      modelsProvider,
      (_, next) {
        if (next.hasError && !result.isCompleted) {
          result.complete(next.error);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      container.read(modelDiscoveryTimeoutProvider),
      const Duration(milliseconds: 20),
    );

    final stopwatch = Stopwatch()..start();
    final error = await result.future;
    expect(error, isA<StateError>());
    expect(error.toString(), contains('not reachable'));

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });
}
