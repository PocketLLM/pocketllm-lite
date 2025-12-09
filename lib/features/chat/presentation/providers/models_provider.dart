import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/models/ollama_model.dart';

final modelsProvider = FutureProvider<List<OllamaModel>>((ref) async {
  final ollama = ref.watch(ollamaServiceProvider);
  // We can add retry logic or cache here
  return ollama.listModels();
});
