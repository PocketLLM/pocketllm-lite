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

  test(
    'document metadata, chunks, and real vectors survive archive restore',
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
      await store.storeDocument(
        document,
        const [chunk],
        const [
          [1.0, 0.0],
        ],
      );
      final archive = await store.exportArchive();
      await store.deleteDocument('doc-1');

      await store.restoreArchiveAtomically(archive);

      expect((await store.getAllDocuments()).single.filename, 'Evidence.pdf');
      final matches = await store.searchWithScores(const [1.0, 0.0]);
      expect(matches.single.chunk.metadata['page'], 4);
    },
  );

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
    await store.storeDocument(
      document,
      chunks,
      const [
        [1.0, 0.0],
        [0.9, 0.1],
        [0.0, 1.0],
      ],
    );

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

  test(
    'hybrid retrieval uses RRF ranks and includes keyword-only chunks',
    () async {
      final store = VectorStoreService();
      final document = IngestedDocument(
        id: 'doc-rrf',
        title: 'RRF evidence',
        filename: 'rrf.txt',
        totalChunks: 4,
        sizeBytes: 100,
        ingestedAt: DateTime.utc(2026),
      );
      const chunks = [
        DocumentChunk(
          id: 'lexical-only',
          documentId: 'doc-rrf',
          content: 'Berlin launch logistics schedule and launch details.',
          index: 0,
        ),
        DocumentChunk(
          id: 'semantic-first',
          documentId: 'doc-rrf',
          content: 'Travel planning notes for the northern region.',
          index: 1,
        ),
        DocumentChunk(
          id: 'both-lists',
          documentId: 'doc-rrf',
          content: 'Berlin launch date and access details.',
          index: 2,
        ),
        DocumentChunk(
          id: 'unrelated',
          documentId: 'doc-rrf',
          content: 'A recipe for sourdough bread.',
          index: 3,
        ),
      ];
      await store.storeDocument(
        document,
        chunks,
        const [
          [0.0, 1.0],
          [1.0, 0.0],
          [0.9, 0.1],
          [0.0, 0.0],
        ],
      );

      final results = await store.searchHybrid(
        queryText: 'Berlin launch logistics',
        queryEmbedding: const [1.0, 0.0],
        topK: 4,
      );

      expect(
          results.map((result) => result.chunk.id), contains('lexical-only'));
      expect(
        results.map((result) => result.chunk.id),
        contains('semantic-first'),
      );
      expect(results.map((result) => result.chunk.id), contains('both-lists'));
      expect(
        results.map((result) => result.chunk.id),
        isNot(contains('unrelated')),
      );
      expect(
        results.where((result) => result.chunk.id == 'both-lists'),
        hasLength(1),
      );
      expect(
        results
            .firstWhere((result) => result.chunk.id == 'both-lists')
            .fusedScore,
        greaterThan(
          results
              .firstWhere((result) => result.chunk.id == 'semantic-first')
              .fusedScore,
        ),
      );
    },
  );

  test(
    'RRF rank ties are deterministic and shared candidates are fused once',
    () async {
      final store = VectorStoreService();
      final document = IngestedDocument(
        id: 'doc-ties',
        title: 'Tie evidence',
        filename: 'ties.txt',
        totalChunks: 3,
        sizeBytes: 50,
        ingestedAt: DateTime.utc(2026),
      );
      const chunks = [
        DocumentChunk(
          id: 'chunk-b',
          documentId: 'doc-ties',
          content: 'Berlin launch',
          index: 0,
        ),
        DocumentChunk(
          id: 'chunk-a',
          documentId: 'doc-ties',
          content: 'Berlin launch',
          index: 1,
        ),
        DocumentChunk(
          id: 'chunk-c',
          documentId: 'doc-ties',
          content: 'Unrelated material',
          index: 2,
        ),
      ];
      await store.storeDocument(
        document,
        chunks,
        const [
          [1.0, 0.0],
          [1.0, 0.0],
          [0.0, 1.0],
        ],
      );

      final first = await store.searchHybrid(
        queryText: 'Berlin launch',
        queryEmbedding: const [1.0, 0.0],
        topK: 3,
      );
      final second = await store.searchHybrid(
        queryText: 'Berlin launch',
        queryEmbedding: const [1.0, 0.0],
        topK: 3,
      );

      expect(
        first.map((result) => result.chunk.id).toList(),
        second.map((result) => result.chunk.id).toList(),
      );
      expect(
        first.map((result) => result.chunk.id).toSet(),
        hasLength(first.length),
      );
      expect(
        first.map((result) => result.chunk.id),
        containsAll(['chunk-a', 'chunk-b']),
      );
    },
  );

  test(
    'hybrid retrieval supports a lexical-only corpus with no embeddings',
    () async {
      final store = VectorStoreService();
      final document = IngestedDocument(
        id: 'doc-keyword',
        title: 'Keyword-only',
        filename: 'keyword.txt',
        totalChunks: 1,
        sizeBytes: 20,
        ingestedAt: DateTime.utc(2026),
        metadata: const {'retrievalMode': 'keyword'},
      );
      const chunk = DocumentChunk(
        id: 'keyword-chunk',
        documentId: 'doc-keyword',
        content: 'The Berlin office opens on Tuesday.',
        index: 0,
      );
      await store.storeDocument(document, const [chunk], null);

      final results = await store.searchHybrid(
        queryText: 'Berlin office',
        queryEmbedding: const [1.0, 0.0],
      );

      expect(results.map((result) => result.chunk.id), ['keyword-chunk']);
      expect(results.single.semanticScore, 0);
      expect(results.single.keywordScore, greaterThan(0));
    },
  );
}
