import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_service.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main.dart');
});

final ollamaServiceProvider = Provider<OllamaService>((ref) {
  return OllamaService();
});

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});
