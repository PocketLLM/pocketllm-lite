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
    expect(context.promptContext, contains('do not contain the answer'));
  });
}
