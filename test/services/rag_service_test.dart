import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:pocketllm_lite/services/rag_service.dart';
import 'package:pocketllm_lite/services/vector_store_service.dart';

void main() {
  test('retrieved context preserves exact filename and page citations', () {
    const chunk = DocumentChunk(
      id: 'chunk-1',
      documentId: 'doc-1',
      content: 'The verified passage text.',
      index: 0,
      metadata: {'filename': 'Evidence.pdf', 'page': 7},
    );
    const context = RetrievedDocumentContext([
      DocumentSearchResult(chunk, 0.91),
    ]);

    expect(context.promptContext, contains('[Evidence.pdf, page 7]'));
    expect(context.promptContext, contains('The verified passage text.'));
    expect(
      context.promptContext,
      contains('[Source 1] [Evidence.pdf, page 7]'),
    );
    expect(context.promptContext, contains('do not contain the answer'));
  });

  test('unpaged text sources are cited by section, never as a page', () {
    const chunk = DocumentChunk(
      id: 'chunk-2',
      documentId: 'doc-2',
      content: 'A note from a plain text file.',
      index: 3,
      metadata: {'filename': 'notes.txt', 'section': 4},
    );
    const context = RetrievedDocumentContext([
      DocumentSearchResult(chunk, 0.5),
    ]);

    expect(context.promptContext, contains('[notes.txt, section 4]'));
    expect(context.promptContext, isNot(contains('page')));
  });
}
