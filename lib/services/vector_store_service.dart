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
    if (chunks.length != embeddings.length) {
      throw ArgumentError(
        'Every document chunk must have one real embedding vector.',
      );
    }
    if (embeddings.any((vector) => vector.isEmpty)) {
      throw ArgumentError('Document embeddings cannot be empty.');
    }

    final writtenIds = <String>[];
    try {
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final embedding = embeddings[i];
        await _chunksBox.put(chunk.id, chunk.toJson());
        await _embeddingsBox.put(chunk.id, {
          'vector': embedding,
          'schemaVersion': 2,
        });
        writtenIds.add(chunk.id);
      }
      // The document record is the commit marker and is written last.
      await _documentsBox.put(doc.id, doc.toJson());
    } catch (_) {
      await _chunksBox.deleteAll(writtenIds);
      await _embeddingsBox.deleteAll(writtenIds);
      rethrow;
    }
  }

  Future<List<IngestedDocument>> getAllDocuments() async {
    await init();
    return _documentsBox.values
        .map((map) => IngestedDocument.fromJson(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<Map<String, dynamic>> exportArchive() async {
    await init();
    return {
      'schemaVersion': 2,
      'documents': {
        for (final entry in _documentsBox.toMap().entries)
          entry.key.toString(): Map<String, dynamic>.from(entry.value),
      },
      'chunks': {
        for (final entry in _chunksBox.toMap().entries)
          entry.key.toString(): Map<String, dynamic>.from(entry.value),
      },
      'embeddings': {
        for (final entry in _embeddingsBox.toMap().entries)
          entry.key.toString(): Map<String, dynamic>.from(entry.value),
      },
    };
  }

  Future<void> restoreArchiveAtomically(Map<String, dynamic> archive) async {
    await init();
    if (archive.isEmpty) return;
    if (archive['schemaVersion'] != 2) {
      throw const FormatException('Unsupported document index version.');
    }
    final documents = _stringMapOfMaps(archive['documents']);
    final chunks = _stringMapOfMaps(archive['chunks']);
    final embeddings = _stringMapOfMaps(archive['embeddings']);

    final documentIds = <String>{};
    for (final entry in documents.entries) {
      final document = IngestedDocument.fromJson(entry.value);
      if (document.id != entry.key) {
        throw const FormatException('Document index key mismatch.');
      }
      documentIds.add(document.id);
    }
    for (final entry in chunks.entries) {
      final chunk = DocumentChunk.fromJson(entry.value);
      if (chunk.id != entry.key || !documentIds.contains(chunk.documentId)) {
        throw const FormatException('Document chunk metadata is inconsistent.');
      }
      final embedding = embeddings[entry.key];
      if (embedding == null ||
          embedding['vector'] is! List ||
          (embedding['vector'] as List).isEmpty) {
        throw const FormatException('A document chunk has no embedding.');
      }
      for (final value in embedding['vector'] as List) {
        if (value is! num) {
          throw const FormatException('Embedding values must be numeric.');
        }
      }
    }
    if (embeddings.keys.any((key) => !chunks.containsKey(key))) {
      throw const FormatException('The document index has orphan embeddings.');
    }

    final documentSnapshot = Map<dynamic, Map>.from(_documentsBox.toMap());
    final chunkSnapshot = Map<dynamic, Map>.from(_chunksBox.toMap());
    final embeddingSnapshot = Map<dynamic, Map>.from(_embeddingsBox.toMap());
    try {
      await _documentsBox.putAll(documents);
      await _chunksBox.putAll(chunks);
      await _embeddingsBox.putAll(embeddings);
    } catch (error) {
      await _documentsBox.clear();
      await _documentsBox.putAll(documentSnapshot);
      await _chunksBox.clear();
      await _chunksBox.putAll(chunkSnapshot);
      await _embeddingsBox.clear();
      await _embeddingsBox.putAll(embeddingSnapshot);
      throw StateError(
        'Document restore failed and the previous index was restored: $error',
      );
    }
  }

  Map<String, Map<String, dynamic>> _stringMapOfMaps(dynamic value) {
    final source = Map<dynamic, dynamic>.from(value as Map? ?? const {});
    return source.map(
      (key, item) => MapEntry(
        key.toString(),
        Map<String, dynamic>.from(item as Map),
      ),
    );
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
    double minimumSimilarity = 0.15,
  }) async {
    final results = await searchWithScores(
      queryEmbedding,
      topK: topK,
      filterDocId: filterDocId,
      minimumSimilarity: minimumSimilarity,
    );
    return results.map((result) => result.chunk).toList(growable: false);
  }

  Future<List<DocumentSearchResult>> searchWithScores(
    List<double> queryEmbedding, {
    int topK = 5,
    String? filterDocId,
    double minimumSimilarity = 0.15,
  }) async {
    await init();
    if (queryEmbedding.isEmpty) return const [];

    final results = <DocumentSearchResult>[];

    for (var key in _embeddingsBox.keys) {
      final chunkMap = _chunksBox.get(key);
      if (chunkMap == null) continue;

      final chunk = DocumentChunk.fromJson(Map<String, dynamic>.from(chunkMap));
      if (filterDocId != null && chunk.documentId != filterDocId) continue;

      final embedMap = _embeddingsBox.get(key);
      if (embedMap == null || !embedMap.containsKey('vector')) continue;

      final vector = List<double>.from(embedMap['vector']);
      final similarity = _cosineSimilarity(queryEmbedding, vector);

      if (similarity >= minimumSimilarity) {
        results.add(DocumentSearchResult(chunk, similarity));
      }
    }

    // Sort descending by similarity
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(topK).toList(growable: false);
  }

  Future<List<DocumentSearchResult>> searchHybrid({
    required String queryText,
    required List<double> queryEmbedding,
    int topK = 5,
    String? filterDocId,
    double denseWeight = 0.6,
    double lambdaMmr = 0.75,
  }) async {
    await init();
    if (queryText.trim().isEmpty || queryEmbedding.isEmpty) return const [];
    if (denseWeight < 0 || denseWeight > 1) {
      throw ArgumentError.value(denseWeight, 'denseWeight', 'must be 0 to 1');
    }
    if (lambdaMmr < 0 || lambdaMmr > 1) {
      throw ArgumentError.value(lambdaMmr, 'lambdaMmr', 'must be 0 to 1');
    }

    final candidates = <_DocumentCandidate>[];
    for (final key in _chunksBox.keys) {
      final chunkMap = _chunksBox.get(key);
      final embeddingMap = _embeddingsBox.get(key);
      if (chunkMap == null || embeddingMap == null) continue;
      final chunk = DocumentChunk.fromJson(Map<String, dynamic>.from(chunkMap));
      if (filterDocId != null && chunk.documentId != filterDocId) continue;
      final rawVector = embeddingMap['vector'];
      if (rawVector is! List) continue;
      final vector =
          rawVector.map((value) => (value as num).toDouble()).toList();
      if (vector.length != queryEmbedding.length || vector.isEmpty) continue;
      candidates.add(_DocumentCandidate(chunk: chunk, embedding: vector));
    }
    if (candidates.isEmpty) return const [];

    final queryTerms = _terms(queryText);
    final corpus = candidates
        .map((candidate) => _terms(candidate.chunk.content))
        .toList(growable: false);
    final averageLength = corpus.fold<int>(
          0,
          (sum, document) => sum + document.length,
        ) /
        max(1, corpus.length);

    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final dense = max(
        0.0,
        _cosineSimilarity(queryEmbedding, candidate.embedding),
      );
      final lexical = _normalizedBm25(
        queryTerms: queryTerms,
        documentTerms: corpus[index],
        corpus: corpus,
        averageDocumentLength: averageLength,
      );
      candidate.relevance =
          (denseWeight * dense) + ((1 - denseWeight) * lexical);
    }

    final selected = <_DocumentCandidate>[];
    final remaining = [...candidates];
    while (remaining.isNotEmpty && selected.length < topK) {
      remaining.sort((left, right) {
        final leftScore = _documentMmr(left, selected, lambdaMmr);
        final rightScore = _documentMmr(right, selected, lambdaMmr);
        return rightScore.compareTo(leftScore);
      });
      selected.add(remaining.removeAt(0));
    }
    return selected
        .where((candidate) => candidate.relevance > 0)
        .map(
          (candidate) =>
              DocumentSearchResult(candidate.chunk, candidate.relevance),
        )
        .toList(growable: false);
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

  double _documentMmr(
    _DocumentCandidate candidate,
    List<_DocumentCandidate> selected,
    double lambda,
  ) {
    if (selected.isEmpty) return candidate.relevance;
    var maximumSimilarity = 0.0;
    for (final existing in selected) {
      maximumSimilarity = max(
        maximumSimilarity,
        _cosineSimilarity(candidate.embedding, existing.embedding).abs(),
      );
    }
    return (lambda * candidate.relevance) - ((1 - lambda) * maximumSimilarity);
  }

  double _normalizedBm25({
    required List<String> queryTerms,
    required List<String> documentTerms,
    required List<List<String>> corpus,
    required double averageDocumentLength,
  }) {
    if (queryTerms.isEmpty || documentTerms.isEmpty) return 0;
    const k1 = 1.2;
    const b = 0.75;
    var score = 0.0;
    for (final term in queryTerms.toSet()) {
      final frequency = documentTerms.where((token) => token == term).length;
      if (frequency == 0) continue;
      final containing =
          corpus.where((document) => document.contains(term)).length;
      final idf = log(
        1 + ((corpus.length - containing + 0.5) / (containing + 0.5)),
      );
      final denominator = frequency +
          k1 *
              (1 -
                  b +
                  b * documentTerms.length / max(1, averageDocumentLength));
      score += idf * (frequency * (k1 + 1)) / denominator;
    }
    return 1 - exp(-score);
  }

  List<String> _terms(String text) => RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .toList(growable: false);
}

class _DocumentCandidate {
  final DocumentChunk chunk;
  final List<double> embedding;
  double relevance;

  _DocumentCandidate({
    required this.chunk,
    required this.embedding,
  }) : relevance = 0;
}

class DocumentSearchResult {
  final DocumentChunk chunk;
  final double similarity;

  const DocumentSearchResult(this.chunk, this.similarity);
}
