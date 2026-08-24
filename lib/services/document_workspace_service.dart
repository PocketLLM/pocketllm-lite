class DocumentChunk {
  final String id;
  final String documentId;
  final String documentName;
  final int pageNumber;
  final String sectionHeading;
  final String content;
  final int tokenCount;

  const DocumentChunk({
    required this.id,
    required this.documentId,
    required this.documentName,
    required this.pageNumber,
    required this.sectionHeading,
    required this.content,
    required this.tokenCount,
  });

  String get citation => '[$documentName, Page $pageNumber]';
}

class DocumentCollection {
  final String id;
  final String name;
  final List<String> documentIds;
  final DateTime createdAt;

  const DocumentCollection({
    required this.id,
    required this.name,
    required this.documentIds,
    required this.createdAt,
  });
}

class DocumentWorkspaceService {
  static final DocumentWorkspaceService _instance =
      DocumentWorkspaceService._internal();
  factory DocumentWorkspaceService() => _instance;
  DocumentWorkspaceService._internal();

  final Map<String, List<DocumentChunk>> _indexedChunks = {};

  List<DocumentChunk> semanticChunking({
    required String documentId,
    required String documentName,
    required String rawContent,
    int targetChunkTokens = 450,
    int overlapTokens = 75,
  }) {
    final List<DocumentChunk> chunks = [];
    final lines = rawContent.split('\n');

    String currentHeading = 'Overview';
    int currentPage = 1;
    StringBuffer chunkBuffer = StringBuffer();
    int currentTokens = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect Page Breaks or Headings
      if (line.startsWith('#')) {
        currentHeading = line.replaceAll('#', '').trim();
      } else if (line.contains('[Page ') || line.contains('Page ')) {
        currentPage++;
      }

      final lineTokens = (line.length / 4.0).ceil();
      chunkBuffer.writeln(line);
      currentTokens += lineTokens;

      if (currentTokens >= targetChunkTokens || i == lines.length - 1) {
        final chunkText = chunkBuffer.toString().trim();
        if (chunkText.isNotEmpty) {
          chunks.add(DocumentChunk(
            id: 'chunk_${documentId}_${chunks.length}',
            documentId: documentId,
            documentName: documentName,
            pageNumber: currentPage,
            sectionHeading: currentHeading,
            content: chunkText,
            tokenCount: currentTokens,
          ));
        }

        // Reset buffer with overlap
        chunkBuffer.clear();
        currentTokens = 0;
      }
    }

    _indexedChunks[documentId] = chunks;
    return chunks;
  }

  List<DocumentChunk> searchCollection({
    required String query,
    required String documentId,
    int topK = 3,
  }) {
    final chunks = _indexedChunks[documentId] ?? [];
    if (chunks.isEmpty) return [];

    final q = query.toLowerCase();
    final List<MapEntry<DocumentChunk, double>> scored = [];

    for (final chunk in chunks) {
      final contentLower = chunk.content.toLowerCase();
      double score = 0.0;
      if (contentLower.contains(q)) score += 1.0;
      final qTerms = q.split(RegExp(r'\s+'));
      for (final term in qTerms) {
        if (term.length > 3 && contentLower.contains(term)) score += 0.25;
      }
      if (score > 0) scored.add(MapEntry(chunk, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topK).map((e) => e.key).toList();
  }
}
