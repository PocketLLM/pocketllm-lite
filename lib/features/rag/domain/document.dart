class DocumentChunk {
  final String id;
  final String documentId;
  final String content;
  final int index;
  final Map<String, dynamic> metadata;

  const DocumentChunk({
    required this.id,
    required this.documentId,
    required this.content,
    required this.index,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'content': content,
    'index': index,
    'metadata': metadata,
  };

  factory DocumentChunk.fromJson(Map<String, dynamic> json) => DocumentChunk(
    id: json['id'],
    documentId: json['documentId'],
    content: json['content'],
    index: json['index'],
    metadata: json['metadata'] ?? {},
  );
}

class IngestedDocument {
  final String id;
  final String title;
  final String filename;
  final int totalChunks;
  final int sizeBytes;
  final DateTime ingestedAt;
  final Map<String, dynamic> metadata;

  const IngestedDocument({
    required this.id,
    required this.title,
    required this.filename,
    required this.totalChunks,
    required this.sizeBytes,
    required this.ingestedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filename': filename,
    'totalChunks': totalChunks,
    'sizeBytes': sizeBytes,
    'ingestedAt': ingestedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory IngestedDocument.fromJson(Map<String, dynamic> json) =>
      IngestedDocument(
        id: json['id'],
        title: json['title'],
        filename: json['filename'],
        totalChunks: json['totalChunks'],
        sizeBytes: json['sizeBytes'],
        ingestedAt: DateTime.parse(json['ingestedAt']),
        metadata: json['metadata'] ?? {},
      );
}
