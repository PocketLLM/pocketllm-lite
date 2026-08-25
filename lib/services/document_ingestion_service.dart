import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../features/rag/domain/document.dart';
import 'context_budget_manager.dart';

class DocumentParseError implements Exception {
  final String message;
  final Object? cause;

  const DocumentParseError(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class _ExtractedPage {
  final int number;
  final String text;
  const _ExtractedPage(this.number, this.text);
}

class DocumentIngestionService {
  final Uuid _uuid;
  final ContextBudgetManager _tokenizer;

  DocumentIngestionService({
    Uuid uuid = const Uuid(),
    ContextBudgetManager? tokenizer,
  })  : _uuid = uuid,
        _tokenizer = tokenizer ?? ContextBudgetManager();

  Future<List<_ExtractedPage>> _extractPages(
    File file,
    String extension,
  ) async {
    try {
      switch (extension) {
        case '.txt':
        case '.md':
        case '.csv':
          return [_ExtractedPage(1, await file.readAsString())];
        case '.pdf':
          final bytes = await file.readAsBytes();
          final document = PdfDocument(inputBytes: bytes);
          try {
            final extractor = PdfTextExtractor(document);
            return List.generate(
              document.pages.count,
              (index) => _ExtractedPage(
                index + 1,
                extractor.extractText(
                  startPageIndex: index,
                  endPageIndex: index,
                ),
              ),
              growable: false,
            );
          } finally {
            document.dispose();
          }
        default:
          throw DocumentParseError('Unsupported file type: $extension');
      }
    } on DocumentParseError {
      rethrow;
    } catch (error) {
      throw DocumentParseError('Could not extract document text.', error);
    }
  }

  List<DocumentChunk> _chunkPages(
    String documentId,
    List<_ExtractedPage> pages, {
    int targetTokens = 450,
    int overlapTokens = 75,
  }) {
    if (targetTokens <= 0 ||
        overlapTokens < 0 ||
        overlapTokens >= targetTokens) {
      throw ArgumentError('Chunk token settings are invalid.');
    }
    final chunks = <DocumentChunk>[];
    for (final page in pages) {
      final paragraphs = page.text
          .replaceAll('\r\n', '\n')
          .split(RegExp(r'\n\s*\n|(?<=[.!?])\s+(?=[A-Z0-9])'))
          .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      var cursor = 0;
      while (cursor < paragraphs.length) {
        final selected = <String>[];
        var tokens = 0;
        var index = cursor;
        while (index < paragraphs.length) {
          final paragraphTokens = _tokenizer.estimateTokens(paragraphs[index]);
          if (selected.isNotEmpty && tokens + paragraphTokens > targetTokens) {
            break;
          }
          selected.add(paragraphs[index]);
          tokens += paragraphTokens;
          index++;
        }
        if (selected.isEmpty) {
          selected.add(paragraphs[cursor]);
          index = cursor + 1;
          tokens = _tokenizer.estimateTokens(paragraphs[cursor]);
        }
        final content = selected.join('\n\n');
        chunks.add(
          DocumentChunk(
            id: _uuid.v4(),
            documentId: documentId,
            content: content,
            index: chunks.length,
            metadata: {
              'page': page.number,
              'tokenCount': tokens,
              'citation': 'Page ${page.number}',
            },
          ),
        );

        var retainedTokens = 0;
        var nextCursor = index;
        while (nextCursor > cursor + 1 && retainedTokens < overlapTokens) {
          nextCursor--;
          retainedTokens += _tokenizer.estimateTokens(paragraphs[nextCursor]);
        }
        cursor = nextCursor > cursor ? nextCursor : index;
      }
    }
    return chunks;
  }

  Future<Map<String, dynamic>> ingestFile(File file) async {
    if (!await file.exists()) {
      throw const DocumentParseError('The selected document no longer exists.');
    }
    final extension = p.extension(file.path).toLowerCase();
    final filename = p.basename(file.path);
    final pages = await _extractPages(file, extension);
    if (pages.every((page) => page.text.trim().isEmpty)) {
      throw const DocumentParseError(
        'No selectable text was found. Scanned PDFs require OCR before indexing.',
      );
    }

    final documentId = _uuid.v4();
    final chunks = _chunkPages(documentId, pages);
    final document = IngestedDocument(
      id: documentId,
      title: p.basenameWithoutExtension(filename),
      filename: filename,
      totalChunks: chunks.length,
      sizeBytes: await file.length(),
      ingestedAt: DateTime.now(),
      metadata: {
        'format': extension.replaceFirst('.', ''),
        'pageCount': pages.length,
        'schemaVersion': 2,
      },
    );
    return {'document': document, 'chunks': chunks};
  }
}
