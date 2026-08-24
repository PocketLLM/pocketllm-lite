import 'hybrid_retrieval_service.dart';
import 'inference_service.dart';
import 'inference_service_factory.dart';
import 'local_memory_service.dart';

class GenerationResult {
  final String text;
  final InferenceMetrics metrics;
  final List<UserMemoryEntry> memoriesUsed;

  const GenerationResult({
    required this.text,
    required this.metrics,
    required this.memoriesUsed,
  });
}

class PreparedGeneration {
  final ChatRequest request;
  final List<UserMemoryEntry> memoriesUsed;

  const PreparedGeneration(this.request, this.memoriesUsed);
}

class GenerationPipeline {
  final Future<InferenceService> Function(String modelId) _resolveInference;
  final LocalMemoryService _memoryService;
  final HybridRetrievalService _retrievalService;

  GenerationPipeline({
    InferenceServiceFactory? inferenceFactory,
    Future<InferenceService> Function(String modelId)? resolveInference,
    LocalMemoryService? memoryService,
    HybridRetrievalService? retrievalService,
  })  : assert(inferenceFactory != null || resolveInference != null),
        _resolveInference =
            resolveInference ?? inferenceFactory!.chooseForModel,
        _memoryService = memoryService ?? LocalMemoryService(),
        _retrievalService = retrievalService ?? HybridRetrievalService();

  Future<PreparedGeneration> prepare(ChatRequest request) async {
    final query = request.messages
        .where((message) => message.role == 'user')
        .map((message) => message.content)
        .lastOrNull;
    if (query == null || query.trim().isEmpty) {
      return PreparedGeneration(request, const []);
    }
    final selected = _retrievalService.retrieveMemories(
      userQuery: query,
      candidateMemories: _memoryService.getMemories(enabledOnly: true),
      topK: 5,
    );
    if (selected.isEmpty) return PreparedGeneration(request, const []);
    final memories =
        selected.map((result) => result.memory).toList(growable: false);
    final memoryContext = StringBuffer('\n\nRelevant user memories:\n');
    for (final memory in memories) {
      memoryContext.writeln('- ${memory.fact}');
    }
    return PreparedGeneration(
      ChatRequest(
        modelId: request.modelId,
        messages: request.messages,
        systemPrompt:
            '${request.systemPrompt ?? ''}${memoryContext.toString()}',
        temperature: request.temperature,
        topP: request.topP,
        topK: request.topK,
        maxTokens: request.maxTokens,
      ),
      memories,
    );
  }

  Stream<ChatToken> stream(ChatRequest request) async* {
    final prepared = await prepare(request);
    final service = await _resolveInference(request.modelId);
    yield* service.chatStream(prepared.request);
  }

  Future<GenerationResult> complete(ChatRequest request) async {
    final prepared = await prepare(request);
    final service = await _resolveInference(request.modelId);
    final buffer = StringBuffer();
    await for (final token in service.chatStream(prepared.request)) {
      buffer.write(token.text);
    }
    return GenerationResult(
      text: buffer.toString(),
      metrics: await service.getMetrics(),
      memoriesUsed: prepared.memoriesUsed,
    );
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
