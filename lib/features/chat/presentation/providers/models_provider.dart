import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../providers/model_manager_provider.dart';
import '../../../../models/local_model.dart';
import '../../domain/models/ollama_model.dart';

class UnifiedModel {
  final String id;
  final String name;
  final bool isLocal;
  final int size;

  UnifiedModel({
    required this.id,
    required this.name,
    required this.isLocal,
    required this.size,
  });
}

final modelsProvider = FutureProvider<List<OllamaModel>>((ref) async {
  final ollama = ref.watch(ollamaServiceProvider);
  return ollama.listModels();
});

final unifiedModelsProvider = FutureProvider<List<UnifiedModel>>((ref) async {
  final localState = ref.watch(modelManagerProvider);
  final List<UnifiedModel> list = [];

  // 1. Add all downloaded local models
  for (final m in localState.models.values) {
    if (m.status == DownloadStatus.downloaded) {
      list.add(UnifiedModel(
        id: m.id,
        name: m.name,
        isLocal: true,
        size: m.fileSizeInBytes,
      ));
    }
  }

  // 2. Add Ollama models if connected
  try {
    final ollamaModels = await ref.watch(modelsProvider.future);
    for (final om in ollamaModels) {
      // Avoid duplicate IDs
      if (!list.any((item) => item.id == om.name)) {
        list.add(UnifiedModel(
          id: om.name,
          name: om.name,
          isLocal: false,
          size: om.size,
        ));
      }
    }
  } catch (_) {
    // Fail silently if Ollama is offline/unreachable
  }

  return list;
});
