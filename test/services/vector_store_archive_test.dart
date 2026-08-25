import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:pocketllm_lite/services/vector_store_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm-vector-');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('document metadata, chunks, and real vectors survive archive restore',
      () async {
    final store = VectorStoreService();
    final document = IngestedDocument(
      id: 'doc-1',
      title: 'Evidence',
      filename: 'Evidence.pdf',
      totalChunks: 1,
      sizeBytes: 42,
      ingestedAt: DateTime.utc(2026),
    );
    const chunk = DocumentChunk(
      id: 'chunk-1',
      documentId: 'doc-1',
      content: 'Verified evidence',
      index: 0,
      metadata: {'page': 4, 'filename': 'Evidence.pdf'},
    );
    await store.storeDocument(document, const [
      chunk
    ], const [
      [1.0, 0.0],
    ]);
    final archive = await store.exportArchive();
    await store.deleteDocument('doc-1');

    await store.restoreArchiveAtomically(archive);

    expect((await store.getAllDocuments()).single.filename, 'Evidence.pdf');
    final matches = await store.searchWithScores(const [1.0, 0.0]);
    expect(matches.single.chunk.metadata['page'], 4);
  });

  test('invalid archives are rejected before changing the index', () async {
    final store = VectorStoreService();
    await expectLater(
      store.restoreArchiveAtomically({
        'schemaVersion': 2,
        'documents': <String, dynamic>{},
        'chunks': {
          'orphan': {
            'id': 'orphan',
            'documentId': 'missing',
            'content': 'bad',
            'index': 0,
            'metadata': <String, dynamic>{},
          },
        },
        'embeddings': {
          'orphan': {
            'vector': [1.0],
          },
        },
      }),
      throwsFormatException,
    );
    expect(await store.getAllDocuments(), isEmpty);
  });

  test('hybrid retrieval fuses real cosine, BM25, and MMR diversity', () async {
    final store = VectorStoreService();
    final document = IngestedDocument(
      id: 'doc-hybrid',
      title: 'Hybrid evidence',
      filename: 'hybrid.pdf',
      totalChunks: 3,
      sizeBytes: 100,
      ingestedAt: DateTime.utc(2026),
    );
    const chunks = [
      DocumentChunk(
        id: 'dense-only',
        documentId: 'doc-hybrid',
        content: 'General travel background without the requested place.',
        index: 0,
      ),
      DocumentChunk(
        id: 'berlin-primary',
        documentId: 'doc-hybrid',
        content: 'The Berlin launch date is Tuesday.',
        index: 1,
      ),
      DocumentChunk(
        id: 'berlin-diverse',
        documentId: 'doc-hybrid',
        content: 'Berlin logistics require the blue access badge.',
        index: 2,
      ),
    ];
    await store.storeDocument(document, chunks, const [
      [1.0, 0.0],
      [0.9, 0.1],
      [0.0, 1.0],
    ]);

    final results = await store.searchHybrid(
      queryText: 'Berlin launch logistics',
      queryEmbedding: const [1.0, 0.0],
      topK: 2,
      denseWeight: 0.2,
      lambdaMmr: 0.6,
    );

    expect(results.first.chunk.id, 'berlin-primary');
    expect(
      results.map((result) => result.chunk.id),
      contains('berlin-diverse'),
    );
  });
}
