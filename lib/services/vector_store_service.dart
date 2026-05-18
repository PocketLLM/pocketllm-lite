import 'dart:math';
import 'package:hive_ce/hive.dart';
import '../features/rag/domain/document.dart';

class VectorStoreService {
  late Box<Map> _embeddingsBox;
  late Box<Map> _documentsBox;
  late Box<Map> _chunksBox;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _embeddingsBox = await Hive.openBox<Map>('rag_embeddings');
    _documentsBox = await Hive.openBox<Map>('rag_documents');
    _chunksBox = await Hive.openBox<Map>('rag_chunks');
    _isInitialized = true;
  }

  Future<void> storeDocument(
    IngestedDocument doc,
    List<DocumentChunk> chunks,
    List<List<double>> embeddings,
  ) async {
    await init();

    // Store doc
    await _documentsBox.put(doc.id, doc.toJson());

    // Store chunks and their embeddings
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final embedding = embeddings[i];
      await _chunksBox.put(chunk.id, chunk.toJson());
      await _embeddingsBox.put(chunk.id, {'vector': embedding});
    }
  }

  Future<List<IngestedDocument>> getAllDocuments() async {
    await init();
    return _documentsBox.values
        .map((map) => IngestedDocument.fromJson(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<void> deleteDocument(String docId) async {
    await init();
    await _documentsBox.delete(docId);

    final chunkIdsToDelete = _chunksBox.values
        .map((map) => DocumentChunk.fromJson(Map<String, dynamic>.from(map)))
        .where((chunk) => chunk.documentId == docId)
        .map((chunk) => chunk.id)
        .toList();

    await _chunksBox.deleteAll(chunkIdsToDelete);
    await _embeddingsBox.deleteAll(chunkIdsToDelete);
  }

  Future<List<DocumentChunk>> search(
    List<double> queryEmbedding, {
    int topK = 5,
    String? filterDocId,
  }) async {
    await init();

    List<_SimilarityResult> results = [];

    for (var key in _embeddingsBox.keys) {
      final chunkMap = _chunksBox.get(key);
      if (chunkMap == null) continue;

      final chunk = DocumentChunk.fromJson(Map<String, dynamic>.from(chunkMap));
      if (filterDocId != null && chunk.documentId != filterDocId) continue;

      final embedMap = _embeddingsBox.get(key);
      if (embedMap == null || !embedMap.containsKey('vector')) continue;

      final vector = List<double>.from(embedMap['vector']);
      final similarity = _cosineSimilarity(queryEmbedding, vector);

      results.add(_SimilarityResult(chunk, similarity));
    }

    // Sort descending by similarity
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(topK).map((r) => r.chunk).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += pow(a[i], 2);
      normB += pow(b[i], 2);
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}

class _SimilarityResult {
  final DocumentChunk chunk;
  final double similarity;

  _SimilarityResult(this.chunk, this.similarity);
}
