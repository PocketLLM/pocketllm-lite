import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../features/chat/domain/models/chat_session.dart';

class PdfExportService {
  Future<Uint8List> generateChatPdf({
    required List<ChatSession> sessions,
  }) async {
    final pdf = pw.Document();

    // Load a font that supports emojis/unicode if possible,
    // or just use standard fonts. For simplicity in this env, use standard.
    // Ideally we would load a font from assets if we need high unicode support.

    for (final session in sessions) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildHeader(session),
              pw.SizedBox(height: 20),
              if (session.systemPrompt != null &&
                  session.systemPrompt!.isNotEmpty)
                _buildSystemPrompt(session.systemPrompt!),
              pw.SizedBox(height: 20),
              ...session.messages.map((msg) => _buildMessage(msg)),
              pw.Divider(),
            ];
          },
        ),
      );
    }

    return await pdf.save();
  }

  pw.Widget _buildHeader(ChatSession session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          session.title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Model: ${session.model} • Date: ${session.createdAt.toIso8601String().split('T')[0]}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildSystemPrompt(String prompt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'System Prompt',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(prompt, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildMessage(dynamic message) {
    final isUser = message.role == 'user';
    final align = isUser
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start;
    final bg = isUser ? PdfColors.blue100 : PdfColors.grey100;
    final textColor = PdfColors.black;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: align,
        children: [
          pw.Text(
            isUser ? 'You' : 'AI',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: bg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              message.content,
              style: pw.TextStyle(color: textColor, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> generateActivityLogsPdf({
    required List<Map<String, dynamic>> logs,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Activity Logs',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Paragraph(
              text: 'Generated on: ${DateTime.now().toIso8601String()}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Timestamp
                1: const pw.FlexColumnWidth(2), // Action
                2: const pw.FlexColumnWidth(4), // Details
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('Timestamp', isHeader: true),
                    _buildTableCell('Action', isHeader: true),
                    _buildTableCell('Details', isHeader: true),
                  ],
                ),
                // Data Rows
                ...logs.map((log) {
                  final timestamp = log['timestamp'] as String? ?? '';
                  String formattedTime = timestamp;
                  try {
                    final dt = DateTime.parse(timestamp);
                    // Simple formatting: YYYY-MM-DD HH:mm:ss
                    formattedTime =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
                  } catch (_) {}

                  return pw.TableRow(
                    children: [
                      _buildTableCell(formattedTime),
                      _buildTableCell(log['action'] as String? ?? ''),
                      _buildTableCell(log['details'] as String? ?? ''),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
