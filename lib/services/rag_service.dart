import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_ingestion_service.dart';
import 'embedding_service.dart';
import 'vector_store_service.dart';
import '../features/rag/domain/document.dart';
import '../features/rag/domain/rag_models.dart';
import '../core/constants/app_constants.dart';
import '../core/domain/background_task.dart';
import '../core/providers.dart';
import 'background_task_service.dart';
import 'storage_service.dart';

class EmbeddingError implements Exception {
  final String message;
  final Object? cause;
  const EmbeddingError(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class RetrievedDocumentContext {
  final List<DocumentSearchResult> results;
  final RagRetrievalMode mode;

  const RetrievedDocumentContext(
    this.results, {
    this.mode = RagRetrievalMode.hybrid,
  });

  bool get isEmpty => results.isEmpty;

  String get promptContext {
    if (results.isEmpty) return '';
    final buffer = StringBuffer(
      'Use only the retrieved excerpts below for document-specific claims. '
      'Cite the bracketed source label exactly. If the excerpts do not answer '
      'the question, say that the indexed documents do not contain the answer.\n',
    );
    for (final result in results) {
      final chunk = result.chunk;
      final page = chunk.metadata['page'] as int?;
      final filename = chunk.metadata['filename'] as String? ?? 'document';
      final citation = page == null ? '[$filename]' : '[$filename, page $page]';
      buffer.writeln('\n$citation\n${chunk.content}');
    }
    return buffer.toString().trim();
  }

  List<Map<String, dynamic>> get diagnostics => results
      .map(
        (result) => {
          'chunkId': result.chunk.id,
          'documentId': result.chunk.documentId,
          'page': result.chunk.metadata['page'],
          'keywordScore': result.keywordScore,
          'semanticScore': result.semanticScore,
          'fusedScore': result.fusedScore,
          'selectedScore': result.similarity,
          'mode': mode.name,
        },
      )
      .toList(growable: false);
}

class RAGService {
  final DocumentIngestionService _ingestionService;
  final EmbeddingService _embeddingService;
  final VectorStoreService _vectorStore;
  final StorageService _storage;
  final BackgroundTaskService _tasks;

  RAGService(
    this._ingestionService,
    this._embeddingService,
    this._vectorStore,
    this._storage,
    this._tasks,
  );

  RagRetrievalMode get retrievalMode => RagRetrievalMode.parse(
        _storage.getSetting(AppConstants.ragRetrievalModeKey) as String?,
      );

  String? get embeddingModelId =>
      _storage.getSetting(AppConstants.ragEmbeddingModelKey) as String?;

  Future<RagSetupStatus> getSetupStatus() async {
    final mode = retrievalMode;
    final modelId = embeddingModelId;
    var installed = false;
    if (modelId != null &&
        supportedEmbeddingModels.any((model) => model.id == modelId)) {
      installed = await _embeddingService.isModelInstalled(modelId);
    }
    return RagSetupStatus(
      mode: mode,
      embeddingModelId: modelId,
      embeddingModelInstalled: installed,
    );
  }

  Future<void> configure({
    required RagRetrievalMode mode,
    String? embeddingModelId,
  }) async {
    if (mode.requiresEmbedding &&
        !supportedEmbeddingModels
            .any((model) => model.id == embeddingModelId)) {
      throw ArgumentError('Choose a compatible embedding model.');
    }
    await _storage.saveSetting(AppConstants.ragRetrievalModeKey, mode.name);
    if (embeddingModelId == null) {
      await _storage.deleteSetting(AppConstants.ragEmbeddingModelKey);
    } else {
      await _storage.saveSetting(
        AppConstants.ragEmbeddingModelKey,
        embeddingModelId,
      );
    }
  }

  Future<void> init() async {
    await _vectorStore.init();
  }

  Future<void> ingestDocument(File file) async {
    final setup = await getSetupStatus();
    if (!setup.ready) {
      throw const EmbeddingError(
        'Semantic indexing is not ready. Download the selected embedding '
        'model in Model Store, or switch the Knowledge Base to Keyword mode.',
      );
    }
    final task = await _tasks.create(
      type: BackgroundTaskType.documentIndex,
      title: 'Index ${file.uri.pathSegments.last}',
      phase: 'Validating document',
      source: file.path,
      metadata: {
        'retrievalMode': setup.mode.name,
        if (setup.embeddingModelId != null)
          'embeddingModelId': setup.embeddingModelId,
      },
    );
    try {
      await _tasks.start(task.id, phase: 'Extracting pages and chunks');
      final result = await _ingestionService.ingestFile(file);
      final parsed = result['document'] as IngestedDocument;
      final rawChunks = result['chunks'] as List<DocumentChunk>;
      final doc = IngestedDocument(
        id: parsed.id,
        title: parsed.title,
        filename: parsed.filename,
        totalChunks: parsed.totalChunks,
        sizeBytes: parsed.sizeBytes,
        ingestedAt: parsed.ingestedAt,
        metadata: {
          ...parsed.metadata,
          'retrievalMode': setup.mode.name,
          if (setup.embeddingModelId != null)
            'embeddingModelId': setup.embeddingModelId,
        },
      );
      final chunks = rawChunks
          .map(
            (chunk) => DocumentChunk(
              id: chunk.id,
              documentId: chunk.documentId,
              content: chunk.content,
              index: chunk.index,
              metadata: {
                ...chunk.metadata,
                'filename': doc.filename,
                'documentTitle': doc.title,
              },
            ),
          )
          .toList(growable: false);
      await _tasks.report(
        task.id,
        phase: setup.mode.requiresEmbedding
            ? 'Creating embeddings'
            : 'Building keyword index',
        completedUnits: 0,
        totalUnits: chunks.length,
      );
      List<List<double>>? embeddings;
      if (setup.mode.requiresEmbedding) {
        final modelId = setup.embeddingModelId!;
        embeddings = await _embeddingService.generateEmbeddings(
          chunks.map((chunk) => chunk.content).toList(growable: false),
          modelId,
          onProgress: (completed, total) {
            _tasks.report(
              task.id,
              phase: 'Creating embeddings',
              completedUnits: completed,
              totalUnits: total,
              progress: total == 0 ? null : completed / total,
            );
          },
        );
      }
      await _tasks.report(task.id, phase: 'Committing local index');
      await _vectorStore.storeDocument(doc, chunks, embeddings);
      await _tasks.complete(
        task.id,
        phase: 'Indexed ${chunks.length} chunks',
        metadata: {'documentId': doc.id, 'chunkCount': chunks.length},
      );
    } catch (error) {
      await _tasks.fail(
        task.id,
        message: 'The document was not added.',
        action: retrievalMode.requiresEmbedding
            ? 'Check the embedding model, then retry the indexing task.'
            : 'Check that the file contains readable text, then retry.',
        details: error.toString(),
      );
      rethrow;
    }
  }

  Future<List<IngestedDocument>> getDocuments() async {
    return await _vectorStore.getAllDocuments();
  }

  Future<void> deleteDocument(String docId) async {
    await _vectorStore.deleteDocument(docId);
  }

  Future<RetrievedDocumentContext> retrieveContext(
    String query, {
    int topK = 3,
  }) async {
    final setup = await getSetupStatus();
    if (!setup.ready) {
      throw const EmbeddingError(
        'Retrieval needs the selected embedding model. Open Knowledge Base '
        'setup to download it or switch to Keyword mode.',
      );
    }
    if (setup.mode == RagRetrievalMode.keyword) {
      final results = await _vectorStore.searchKeyword(
        queryText: query,
        topK: topK,
      );
      return RetrievedDocumentContext(results, mode: setup.mode);
    }
    final embedding = await _embeddingService.generateEmbedding(
      query,
      setup.embeddingModelId!,
    );
    final results = setup.mode == RagRetrievalMode.semantic
        ? await _vectorStore.searchWithScores(embedding, topK: topK)
        : await _vectorStore.searchHybrid(
            queryText: query,
            queryEmbedding: embedding,
            topK: topK,
          );
    return RetrievedDocumentContext(results, mode: setup.mode);
  }

  @Deprecated(
      'Use retrieveContext and pass promptContext to GenerationPipeline.')
  Future<String> augmentPrompt(String originalPrompt, {int topK = 3}) async {
    final context = await retrieveContext(originalPrompt, topK: topK);
    if (context.isEmpty) return originalPrompt;
    return '${context.promptContext}\n\nUser query:\n$originalPrompt';
  }
}

final documentIngestionServiceProvider = Provider<DocumentIngestionService>((
  ref,
) {
  return DocumentIngestionService();
});

final vectorStoreServiceProvider = Provider<VectorStoreService>((ref) {
  return VectorStoreService();
});

final ragServiceProvider = Provider<RAGService>((ref) {
  return RAGService(
    ref.watch(documentIngestionServiceProvider),
    ref.watch(embeddingServiceProvider),
    ref.watch(vectorStoreServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(backgroundTaskServiceProvider),
  );
});
