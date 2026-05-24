import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/error_log_service.dart';
import '../services/inference_service_factory.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';
import '../services/huggingface_service.dart';
import '../services/tool_calling_service.dart';


final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main.dart');
});

final ollamaServiceProvider = Provider<OllamaService>((ref) {
  return OllamaService();
});

final errorLogServiceProvider = Provider<ErrorLogService>((ref) {
  throw UnimplementedError('ErrorLogService must be initialized in main.dart');
});

final inferenceServiceFactoryProvider = Provider<InferenceServiceFactory>((
  ref,
) {
  return InferenceServiceFactory(
    ollamaService: ref.watch(ollamaServiceProvider),
    errorLogService: ref.watch(errorLogServiceProvider),
  );
});

final huggingFaceServiceProvider = Provider<HuggingFaceService>((ref) {
  return HuggingFaceService();
});

final toolCallingServiceProvider = Provider<ToolCallingService>((ref) {
  return ToolCallingService(ref.watch(storageServiceProvider));
});

// Re-export RAG providers from rag_service.dart
// (They are defined in rag_service.dart and embedding_service.dart)
