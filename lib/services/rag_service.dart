import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_ingestion_service.dart';
import 'embedding_service.dart';
import 'vector_store_service.dart';
import '../features/rag/domain/document.dart';

class RAGService {
  final DocumentIngestionService _ingestionService;
  final EmbeddingService _embeddingService;
  final VectorStoreService _vectorStore;

  // Hardcoded for now. Should be configurable.
  final String embeddingModelId = 'all-minilm-l6-v2';

  RAGService(this._ingestionService, this._embeddingService, this._vectorStore);

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
    final embeddings = await _embeddingService.generateEmbeddings(
      texts,
      embeddingModelId,
    );

    // 3. Store
    await _vectorStore.storeDocument(doc, chunks, embeddings);
  }

  Future<List<IngestedDocument>> getDocuments() async {
    return await _vectorStore.getAllDocuments();
  }

  Future<void> deleteDocument(String docId) async {
    await _vectorStore.deleteDocument(docId);
  }

  Future<String> augmentPrompt(String originalPrompt, {int topK = 3}) async {
    // 1. Embed query
    final queryEmbedding = await _embeddingService.generateEmbedding(
      originalPrompt,
      embeddingModelId,
    );

    // 2. Search
    final chunks = await _vectorStore.search(queryEmbedding, topK: topK);

    if (chunks.isEmpty) return originalPrompt;

    // 3. Build context
    final buffer = StringBuffer();
    buffer.writeln('Context information:');
    buffer.writeln('---------------------');
    for (int i = 0; i < chunks.length; i++) {
      buffer.writeln('Source ${i + 1}:');
      buffer.writeln(chunks[i].content);
      buffer.writeln();
    }
    buffer.writeln('---------------------');
    buffer.writeln('User Query:');
    buffer.writeln(originalPrompt);
    buffer.writeln(
      'Please answer the user query based ONLY on the context provided above. If the context does not contain the answer, say "I cannot answer this based on the provided context."',
    );

    return buffer.toString();
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
