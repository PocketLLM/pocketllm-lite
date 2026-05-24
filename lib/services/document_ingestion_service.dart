import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../features/rag/domain/document.dart';

class DocumentIngestionService {
  final Uuid _uuid = const Uuid();

  /// Reads a file and returns its textual content
  Future<String> _extractText(File file, String extension) async {
    switch (extension) {
      case '.txt':
      case '.md':
      case '.csv':
        return await file.readAsString();
      case '.pdf':
        final bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final String text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      default:
        throw Exception('Unsupported file type: $extension');
    }
  }

  /// Splits text into overlapping chunks based on character count.
  /// A more robust implementation would use a token text splitter.
  List<String> _chunkText(
    String text, {
    int chunkSize = 2000,
    int overlap = 200,
  }) {
    if (text.isEmpty) return [];

    // Clean up excessive whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    List<String> chunks = [];
    int start = 0;

    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) {
        end = text.length;
      } else {
        // Try to find a natural break point (period or space) near the end
        int lastPeriod = text.lastIndexOf('.', end);
        int lastSpace = text.lastIndexOf(' ', end);

        if (lastPeriod > start + (chunkSize / 2)) {
          end = lastPeriod + 1;
        } else if (lastSpace > start + (chunkSize / 2)) {
          end = lastSpace;
        }
      }

      chunks.add(text.substring(start, end).trim());
      start = end - overlap;

      // Prevent infinite loop if overlap is too large relative to progress
      if (start <= 0 || (end - start) <= overlap) {
        start = end;
      }
    }

    return chunks;
  }

  Future<Map<String, dynamic>> ingestFile(File file) async {
    final extension =
        file.path.substring(file.path.lastIndexOf('.')).toLowerCase();
    final filename = file.path.split('/').last;

    final text = await _extractText(file, extension);
    final rawChunks = _chunkText(text);

    final docId = _uuid.v4();
    final doc = IngestedDocument(
      id: docId,
      title: filename, // Could extract title from PDF metadata
      filename: filename,
      totalChunks: rawChunks.length,
      sizeBytes: await file.length(),
      ingestedAt: DateTime.now(),
    );

    final chunks = rawChunks
        .asMap()
        .entries
        .map(
          (e) => DocumentChunk(
            id: _uuid.v4(),
            documentId: docId,
            content: e.value,
            index: e.key,
          ),
        )
        .toList();

    return {'document': doc, 'chunks': chunks};
  }
}
