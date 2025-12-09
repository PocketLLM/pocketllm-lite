import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/ollama_service.dart';
import '../models/ollama_model.dart';
import 'settings_provider.dart';

part 'ollama_provider.g.dart';

@riverpod
OllamaService ollamaService(OllamaServiceRef ref) {
  return OllamaService();
}

@riverpod
class ConnectionStatus extends _$ConnectionStatus {
  @override
  Future<bool> build() async {
    final settings = await ref.watch(settingsProvider.future);
    final service = ref.watch(ollamaServiceProvider);
    return service.checkConnection(settings.ollamaEndpoint);
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
class AvailableModels extends _$AvailableModels {
  @override
  Future<List<OllamaModel>> build() async {
    final settings = await ref.watch(settingsProvider.future);
    final service = ref.watch(ollamaServiceProvider);

    // Only try to fetch if we think we are connected or just try anyway
    return service.listModels(settings.ollamaEndpoint);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteModel(String name) async {
    final settings = await ref.watch(settingsProvider.future);
    final service = ref.watch(ollamaServiceProvider);
    await service.deleteModel(settings.ollamaEndpoint, name);
    ref.invalidateSelf();
  }

  Future<void> pullModel(String name) async {
    final settings = await ref.watch(settingsProvider.future);
    final service = ref.watch(ollamaServiceProvider);
    await service.pullModel(settings.ollamaEndpoint, name);
    // Usually pulling takes time, we might not see it immediately in list
    ref.invalidateSelf();
  }
}
