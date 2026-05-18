import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class EmbeddingService {
  final Ref ref;

  EmbeddingService(this.ref);

  Future<List<double>> generateEmbedding(String text, String modelId) async {
    final inferenceFactory = ref.read(inferenceServiceFactoryProvider);
    final service = await inferenceFactory.chooseForModel(modelId);
    return await service.generateEmbeddings(text, modelId);
  }

  /// Batch embedding generation
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts,
    String modelId,
  ) async {
    // A more optimized implementation would use a native batch API if available.
    List<List<double>> results = [];
    for (var text in texts) {
      results.add(await generateEmbedding(text, modelId));
    }
    return results;
  }
}

final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return EmbeddingService(ref);
});
