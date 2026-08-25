import 'dart:math';

import 'local_memory_service.dart';

class MemorySearchResult {
  final UserMemoryEntry memory;
  final double score;
  final double? embeddingSimilarity;
  final double bm25Score;
  final double recencyScore;
  final String debugReason;

  const MemorySearchResult({
    required this.memory,
    required this.score,
    required this.embeddingSimilarity,
    required this.bm25Score,
    required this.recencyScore,
    required this.debugReason,
  });
}

class HybridRetrievalService {
  static final HybridRetrievalService _instance =
      HybridRetrievalService._internal();
  factory HybridRetrievalService() => _instance;
  HybridRetrievalService._internal();

  List<MemorySearchResult> retrieveMemories({
    required String userQuery,
    required List<UserMemoryEntry> candidateMemories,
    List<double>? queryEmbedding,
    int topK = 5,
    double lambdaMmr = 0.7,
  }) {
    if (lambdaMmr < 0 || lambdaMmr > 1) {
      throw ArgumentError.value(lambdaMmr, 'lambdaMmr', 'must be 0 to 1');
    }
    final enabled =
        candidateMemories.where((memory) => memory.enabled).toList();
    if (enabled.isEmpty || userQuery.trim().isEmpty) return const [];
    final queryTerms = _terms(userQuery);
    final documents = enabled.map((memory) => _terms(memory.fact)).toList();
    final averageLength =
        documents.fold<int>(0, (sum, terms) => sum + terms.length) /
            max(1, documents.length);
    final now = DateTime.now();
    final scored = <MemorySearchResult>[];

    for (var i = 0; i < enabled.length; i++) {
      final memory = enabled[i];
      final dense = queryEmbedding != null && memory.embedding != null
          ? cosineSimilarity(queryEmbedding, memory.embedding!)
          : null;
      final bm25 = _bm25(
        queryTerms: queryTerms,
        documentTerms: documents[i],
        corpus: documents,
        averageDocumentLength: averageLength,
      );
      final daysOld = now.difference(memory.updatedAt).inDays;
      final recency = max(0.0, 1 - (daysOld / 90));
      final retrieval = dense == null ? bm25 : (0.6 * dense) + (0.4 * bm25);
      final score = (0.75 * retrieval) +
          (0.1 * recency) +
          (0.1 * memory.confidence) +
          (memory.pinned ? 0.05 : 0);
      scored.add(
        MemorySearchResult(
          memory: memory,
          score: score,
          embeddingSimilarity: dense,
          bm25Score: bm25,
          recencyScore: recency,
          debugReason: dense == null
              ? 'Lexical-only BM25 ${bm25.toStringAsFixed(3)}; no stored embedding'
              : 'Dense ${dense.toStringAsFixed(3)}, BM25 ${bm25.toStringAsFixed(3)}',
        ),
      );
    }

    final selected = <MemorySearchResult>[];
    final remaining = [...scored];
    while (remaining.isNotEmpty && selected.length < topK) {
      remaining.sort((left, right) {
        final leftMmr = _mmr(left, selected, lambdaMmr);
        final rightMmr = _mmr(right, selected, lambdaMmr);
        return rightMmr.compareTo(leftMmr);
      });
      selected.add(remaining.removeAt(0));
    }
    return selected;
  }

  double cosineSimilarity(List<double> left, List<double> right) {
    if (left.isEmpty || left.length != right.length) {
      throw ArgumentError(
          'Embedding vectors must have the same non-zero length.');
    }
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var i = 0; i < left.length; i++) {
      dot += left[i] * right[i];
      leftNorm += left[i] * left[i];
      rightNorm += right[i] * right[i];
    }
    if (leftNorm == 0 || rightNorm == 0) return 0;
    return (dot / (sqrt(leftNorm) * sqrt(rightNorm))).clamp(-1, 1);
  }

  double _mmr(
    MemorySearchResult candidate,
    List<MemorySearchResult> selected,
    double lambda,
  ) {
    if (selected.isEmpty) return candidate.score;
    var maximumSimilarity = 0.0;
    for (final existing in selected) {
      final left = candidate.memory.embedding;
      final right = existing.memory.embedding;
      final similarity = left != null && right != null
          ? cosineSimilarity(left, right).abs()
          : _jaccard(
              _terms(candidate.memory.fact), _terms(existing.memory.fact));
      maximumSimilarity = max(maximumSimilarity, similarity);
    }
    return (lambda * candidate.score) - ((1 - lambda) * maximumSimilarity);
  }

  double _bm25({
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
      final containing = corpus.where((doc) => doc.contains(term)).length;
      final idf =
          log(1 + ((corpus.length - containing + 0.5) / (containing + 0.5)));
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

  double _jaccard(List<String> left, List<String> right) {
    final a = left.toSet();
    final b = right.toSet();
    if (a.isEmpty && b.isEmpty) return 0;
    return a.intersection(b).length / a.union(b).length;
  }
}
