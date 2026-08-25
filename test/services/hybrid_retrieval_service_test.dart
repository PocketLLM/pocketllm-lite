import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/hybrid_retrieval_service.dart';
import 'package:pocketllm_lite/services/local_memory_service.dart';

void main() {
  late HybridRetrievalService retrievalService;

  setUp(() {
    retrievalService = HybridRetrievalService();
  });

  test(
      'hybrid retrieval scores query against memory candidates with MMR deduplication',
      () {
    final candidateMemories = [
      UserMemoryEntry(
        id: 'mem_1',
        type: MemoryType.preference,
        subject: 'user',
        fact: 'Prefers Flutter and Riverpod state management',
        confidence: 0.95,
        createdAt: DateTime.now(),
        embedding: const [1, 0, 0],
      ),
      UserMemoryEntry(
        id: 'mem_2',
        type: MemoryType.preference,
        subject: 'user',
        fact: 'Prefers Flutter and Riverpod state management', // Duplicate
        confidence: 0.90,
        createdAt: DateTime.now(),
        embedding: const [0.99, 0.01, 0],
      ),
      UserMemoryEntry(
        id: 'mem_3',
        type: MemoryType.personalFact,
        subject: 'user',
        fact: 'Studying machine learning algorithms in Python',
        confidence: 0.85,
        createdAt: DateTime.now(),
        embedding: const [0, 1, 0],
      ),
    ];

    final results = retrievalService.retrieveMemories(
      userQuery: 'How should I structure my Flutter Riverpod project?',
      candidateMemories: candidateMemories,
      queryEmbedding: const [1, 0, 0],
      topK: 2,
    );

    expect(results.length, lessThanOrEqualTo(2));
    expect(results.first.memory.id, equals('mem_1'));
    expect(results.first.embeddingSimilarity, closeTo(1, 0.0001));
    expect(results.first.debugReason, isNot(contains('Simulated')));
  });
}
