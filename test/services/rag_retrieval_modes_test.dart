import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:pocketllm_lite/services/vector_store_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm_rag_modes_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('keyword documents are searchable without embedding vectors', () async {
    final store = VectorStoreService();
    final document = IngestedDocument(
      id: 'doc-keyword',
      title: 'Planets',
      filename: 'planets.txt',
      totalChunks: 2,
      sizeBytes: 100,
      ingestedAt: DateTime.utc(2026, 8, 26),
      metadata: const {'retrievalMode': 'keyword'},
    );
    const chunks = [
      DocumentChunk(
        id: 'earth',
        documentId: 'doc-keyword',
        content: 'Earth has one natural moon.',
        index: 0,
      ),
      DocumentChunk(
        id: 'mars',
        documentId: 'doc-keyword',
        content: 'Mars has two small moons.',
        index: 1,
      ),
    ];
    await store.storeDocument(document, chunks, null);

    final results = await store.searchKeyword(queryText: 'Earth moon');
    expect(results.first.chunk.id, 'earth');
    expect(results.first.keywordScore, greaterThan(0));
    expect(results.first.semanticScore, 0);
  });

  test('semantic results expose the measured cosine score', () async {
    final store = VectorStoreService();
    final document = IngestedDocument(
      id: 'doc-semantic',
      title: 'Vectors',
      filename: 'vectors.txt',
      totalChunks: 2,
      sizeBytes: 100,
      ingestedAt: DateTime.utc(2026, 8, 26),
      metadata: const {'retrievalMode': 'semantic'},
    );
    const chunks = [
      DocumentChunk(
        id: 'aligned',
        documentId: 'doc-semantic',
        content: 'Aligned vector',
        index: 0,
      ),
      DocumentChunk(
        id: 'orthogonal',
        documentId: 'doc-semantic',
        content: 'Orthogonal vector',
        index: 1,
      ),
    ];
    await store.storeDocument(document, chunks, const [
      [1, 0],
      [0, 1],
    ]);

    final results = await store.searchWithScores([1, 0]);
    expect(results.first.chunk.id, 'aligned');
    expect(results.first.semanticScore, closeTo(1, 0.0001));
  });
}
