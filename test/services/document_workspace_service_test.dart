import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/document_workspace_service.dart';

void main() {
  late DocumentWorkspaceService workspaceService;

  setUp(() {
    workspaceService = DocumentWorkspaceService();
  });

  test(
      'semantic chunker preserves headings, pages, and generates inline citations',
      () {
    const rawContent = '''
# Introduction to Local LLMs
Local LLMs execute AI inference entirely on-device without cloud services.
[Page 2]
# Performance Optimization
Quantization Q4_K_M reduces memory bandwidth while retaining accuracy.
''';

    final chunks = workspaceService.semanticChunking(
      documentId: 'doc_1',
      documentName: 'Local_AI_Guide.pdf',
      rawContent: rawContent,
      targetChunkTokens: 20,
    );

    expect(chunks.isNotEmpty, isTrue);
    expect(chunks.first.documentName, equals('Local_AI_Guide.pdf'));
    expect(chunks.first.citation, contains('Local_AI_Guide.pdf'));
  });

  test('collection search matches query terms accurately', () {
    const rawContent =
        'Flutter desktop and mobile applications use Riverpod providers for state management.';
    workspaceService.semanticChunking(
      documentId: 'doc_flutter',
      documentName: 'Flutter_Arch.txt',
      rawContent: rawContent,
    );

    final matches = workspaceService.searchCollection(
      query: 'Riverpod state management',
      documentId: 'doc_flutter',
    );

    expect(matches.isNotEmpty, isTrue);
    expect(matches.first.content, contains('Riverpod'));
  });
}
