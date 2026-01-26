import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/pdf_export_service.dart';

void main() {
  test('PdfExportService generates PDF data', () async {
    final service = PdfExportService();
    final session = ChatSession(
      id: 'test_id',
      title: 'Test Chat',
      model: 'llama3',
      createdAt: DateTime.now(),
      messages: [
        ChatMessage(role: 'user', content: 'Hello', timestamp: DateTime.now()),
        ChatMessage(
          role: 'assistant',
          content: 'Hi there!',
          timestamp: DateTime.now(),
        ),
      ],
    );

    final bytes = await service.generateChatPdf(sessions: [session]);
    expect(bytes, isNotNull);
    expect(bytes.isNotEmpty, true);
    // Basic check for PDF header signature
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
