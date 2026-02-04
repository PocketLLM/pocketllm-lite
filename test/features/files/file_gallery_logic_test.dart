import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/text_file_attachment.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  List<ChatSession> _mockSessions = [];

  void setMockSessions(List<ChatSession> sessions) {
    _mockSessions = sessions;
  }

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }
}

void main() {
  group('File Gallery Logic', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllAttachments returns all attachments from all sessions', () {
      final now = DateTime.now();
      final attachment1 = TextFileAttachment(name: 'a.txt', content: 'a', sizeBytes: 1);
      final attachment2 = TextFileAttachment(name: 'b.txt', content: 'b', sizeBytes: 1);

      final sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'msg1',
              timestamp: now,
              attachments: [attachment1],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'msg2',
              timestamp: now.subtract(const Duration(minutes: 1)),
              attachments: [attachment2],
            ),
          ],
          createdAt: now,
        ),
      ];

      storageService.setMockSessions(sessions);

      final result = storageService.getAllAttachments();
      expect(result.length, 2);
      expect(result[0].attachment.name, 'a.txt'); // Most recent first (now)
      expect(result[1].attachment.name, 'b.txt'); // (now - 1 min)
      expect(result[0].chatTitle, 'Chat 1');
    });
  });
}
