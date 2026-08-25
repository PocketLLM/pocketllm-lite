import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_ingestion_service.dart';
import 'embedding_service.dart';
import 'vector_store_service.dart';
import '../features/rag/domain/document.dart';

class EmbeddingError implements Exception {
  final String message;
  final Object? cause;
  const EmbeddingError(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class RetrievedDocumentContext {
  final List<DocumentSearchResult> results;

  const RetrievedDocumentContext(this.results);

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
}

class RAGService {
  final DocumentIngestionService _ingestionService;
  final EmbeddingService _embeddingService;
  final VectorStoreService _vectorStore;

  final String embeddingModelId;

  RAGService(
    this._ingestionService,
    this._embeddingService,
    this._vectorStore, {
    this.embeddingModelId = 'all-minilm-l6-v2',
  });

  Future<void> init() async {
    await _vectorStore.init();
  }

  Future<void> ingestDocument(File file) async {
    // 1. Ingest & Chunk
    final result = await _ingestionService.ingestFile(file);
    final doc = result['document'] as IngestedDocument;
    final chunks = result['chunks'] as List<DocumentChunk>;

    // 2. Generate Embeddings
    final texts = chunks.map((c) => c.content).toList();
    late final List<List<double>> embeddings;
    try {
      embeddings = await _embeddingService.generateEmbeddings(
        texts,
        embeddingModelId,
      );
    } catch (error) {
      throw EmbeddingError(
        'Document indexing needs a downloaded embedding-capable model '
        '($embeddingModelId). The document was not added.',
        error,
      );
    }

    final chunksWithSource = chunks
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

    // 3. Store
    await _vectorStore.storeDocument(doc, chunksWithSource, embeddings);
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
    // 1. Embed query
    final queryEmbedding = await _embeddingService.generateEmbedding(
      query,
      embeddingModelId,
    );

    // 2. Search
    final results = await _vectorStore.searchHybrid(
      queryText: query,
      queryEmbedding: queryEmbedding,
      topK: topK,
    );
    return RetrievedDocumentContext(results);
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
  );
});
