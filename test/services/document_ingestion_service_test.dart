import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:pocketllm_lite/services/document_ingestion_service.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'pocketllm-document-ingestion-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('text ingestion preserves real source metadata and overlapping chunks',
      () async {
    final file = File('${temporaryDirectory.path}/research_notes.txt');
    await file.writeAsString(
      List.generate(
        30,
        (index) =>
            'Section $index explains a distinct local inference fact in detail.',
      ).join('\n\n'),
    );

    final result = await DocumentIngestionService().ingestFile(file);
    final document = result['document'] as IngestedDocument;
    final chunks = result['chunks'] as List<DocumentChunk>;

    expect(document.filename, 'research_notes.txt');
    expect(document.metadata['pageCount'], 1);
    expect(document.metadata['schemaVersion'], 2);
    expect(chunks, isNotEmpty);
    expect(chunks.every((chunk) => chunk.metadata['page'] == 1), isTrue);
    expect(chunks.every((chunk) => chunk.content.trim().isNotEmpty), isTrue);
  });

  test('empty and unsupported files fail with structured parse errors',
      () async {
    final empty = File('${temporaryDirectory.path}/empty.txt');
    await empty.writeAsString('');
    final unsupported = File('${temporaryDirectory.path}/notes.docx');
    await unsupported.writeAsBytes([1, 2, 3]);

    expect(
      () => DocumentIngestionService().ingestFile(empty),
      throwsA(isA<DocumentParseError>()),
    );
    expect(
      () => DocumentIngestionService().ingestFile(unsupported),
      throwsA(isA<DocumentParseError>()),
    );
  });
}
