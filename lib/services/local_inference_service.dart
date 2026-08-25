import 'dart:io';

import 'package:cactus/cactus.dart' as cactus;
// Pinned Cactus 1.3.0 adapter: using the local context API avoids the public
// wrapper's implicit Supabase metadata requests during otherwise local work.
// ignore: implementation_imports
import 'package:cactus/src/services/context.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'error_log_service.dart';
import 'inference_service.dart';

class LocalInferenceService implements InferenceService {
  final ErrorLogService? _errorLogService;
  final int contextSize;
  int? _handle;
  String? _loadedModelId;
  int _loadedQuantization = 8;
  bool _isGenerating = false;
  InferenceMetrics _lastMetrics = const InferenceMetrics();

  LocalInferenceService({
    ErrorLogService? errorLogService,
    this.contextSize = 2048,
  }) : _errorLogService = errorLogService;

  @override
  Future<bool> isAvailable() async {
    try {
      return (await listModels()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<LLMModel>> listModels() async {
    try {
      final root = await _modelsDirectory();
      if (!await root.exists()) return const [];
      final models = <LLMModel>[];
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final ggufFiles = await entity
            .list(recursive: true, followLinks: false)
            .where((item) =>
                item is File && item.path.toLowerCase().endsWith('.gguf'))
            .cast<File>()
            .toList();
        if (ggufFiles.isEmpty) continue;
        var size = 0;
        for (final file in ggufFiles) {
          size += await file.length();
        }
        final id = p.basename(entity.path);
        models.add(
          LLMModel(
            id: id,
            name: id,
            backend: InferenceBackend.local,
            sizeBytes: size,
            isDownloaded: true,
            quantizationBits: _quantizationFromFiles(ggufFiles),
          ),
        );
      }
      return models;
    } catch (error, stackTrace) {
      await _logLocalError(error, stackTrace, 'Failed to list local models');
      throw InferenceError('Failed to scan installed local models.', error);
    }
  }

  @override
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress}) async {
    try {
      if (_loadedModelId == modelId && _handle != null) {
        onProgress?.call(
          const InferenceProgress(progress: 1, status: 'Model already loaded'),
        );
        return;
      }
      final root = await _modelsDirectory();
      final modelDirectory = Directory(p.join(root.path, modelId));
      if (!await modelDirectory.exists()) {
        throw const InferenceError(
          'Model is not installed in the app model directory.',
        );
      }
      final ggufFiles = await modelDirectory
          .list(recursive: true, followLinks: false)
          .where((item) =>
              item is File && item.path.toLowerCase().endsWith('.gguf'))
          .cast<File>()
          .toList();
      if (ggufFiles.isEmpty) {
        throw const ModelCorruptedError(
          'The model folder does not contain a GGUF file.',
        );
      }

      final existingHandle = _handle;
      if (existingHandle != null) {
        CactusContext.freeContext(existingHandle);
        _handle = null;
        _loadedModelId = null;
      }
      onProgress?.call(
        const InferenceProgress(progress: 0.2, status: 'Validating model'),
      );
      final initialized = await CactusContext.initContext(
        modelDirectory.path,
        contextSize,
      );
      if (initialized.$1 == null) {
        throw InferenceError(
          'Cactus could not initialize this GGUF architecture: ${initialized.$2}',
        );
      }
      _handle = initialized.$1;
      _loadedModelId = modelId;
      _loadedQuantization = _quantizationFromFiles(ggufFiles) ?? 8;
      onProgress?.call(
        const InferenceProgress(progress: 1, status: 'Model loaded'),
      );
    } catch (error, stackTrace) {
      await _logLocalError(error, stackTrace, 'Failed to load local model');
      if (error is InferenceException) rethrow;
      throw InferenceError('Failed to load local model "$modelId".', error);
    }
  }

  @override
  Future<void> unloadModel(String modelId) async {
    if (_loadedModelId == modelId && _handle != null) {
      CactusContext.freeContext(_handle!);
      _handle = null;
      _loadedModelId = null;
    }
  }

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    if (_isGenerating) {
      throw const InferenceError(
        'The local runtime is already generating. Wait or cancel first.',
      );
    }
    await loadModel(request.modelId);
    final handle = _handle;
    if (handle == null) throw const InferenceError('Model is not loaded.');
    _isGenerating = true;
    try {
      CactusContext.resetContext(handle);
      final messages = <cactus.ChatMessage>[
        if (request.systemPrompt?.isNotEmpty ?? false)
          cactus.ChatMessage(content: request.systemPrompt!, role: 'system'),
        ...request.messages.map(
          (message) => cactus.ChatMessage(
            content: message.content,
            role: message.role,
            images: message.images ?? const [],
          ),
        ),
      ];
      final streamed = CactusContext.completionStream(
        handle,
        messages,
        cactus.CactusCompletionParams(
          temperature: request.temperature,
          topK: request.topK,
          topP: request.topP,
          maxTokens: request.maxTokens,
        ),
        _loadedQuantization,
      );
      await for (final chunk in streamed.stream) {
        yield ChatToken(text: chunk);
      }
      final result = await streamed.result;
      _lastMetrics = InferenceMetrics(
        tokensPerSecond: result.tokensPerSecond,
        millisecondsPerToken:
            result.tokensPerSecond > 0 ? 1000 / result.tokensPerSecond : 0,
        totalTime: Duration(milliseconds: result.totalTimeMs.round()),
        promptTokens: result.prefillTokens,
        completionTokens: result.decodeTokens,
      );
      if (!result.success) {
        throw const InferenceError(
          'Local model returned an unsuccessful result.',
        );
      }
    } catch (error, stackTrace) {
      await _logLocalError(error, stackTrace, 'Local inference failed');
      if (error is InferenceException) rethrow;
      throw InferenceError('Local inference failed.', error);
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) async {
    if (_isGenerating) {
      throw const InferenceError(
        'Embedding generation cannot run during local chat generation.',
      );
    }
    await loadModel(modelId);
    final handle = _handle;
    if (handle == null) throw const InferenceError('Model is not loaded.');
    final result = await CactusContext.generateEmbedding(
      handle,
      text,
      _loadedQuantization,
    );
    if (!result.success || result.embeddings.isEmpty) {
      throw InferenceError(
        result.errorMessage ?? 'Embedding generation failed.',
      );
    }
    return result.embeddings;
  }

  @override
  Future<InferenceMetrics> getMetrics() async => _lastMetrics;

  Future<Directory> _modelsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'models'));
  }

  int? _quantizationFromFiles(List<File> files) {
    for (final file in files) {
      final match = RegExp(
        r'(?:^|[._-])Q(\d)(?:_|[.-])',
        caseSensitive: false,
      ).firstMatch(p.basename(file.path));
      if (match != null) return int.tryParse(match.group(1)!);
      final lower = p.basename(file.path).toLowerCase();
      if (lower.contains('f16') || lower.contains('fp16')) return 16;
      if (lower.contains('f32') || lower.contains('fp32')) return 32;
    }
    return null;
  }

  Future<void> _logLocalError(
    Object error,
    StackTrace stackTrace,
    String message,
  ) async {
    await _errorLogService?.logError(
      category: ErrorCategory.inference,
      message: message,
      details: error.toString(),
      stackTrace: stackTrace.toString(),
      suggestedFix:
          'Try a smaller quantized model, reduce context length, or restart the app to free memory.',
    );
  }
}
