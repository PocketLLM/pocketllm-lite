import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/text_file_attachment.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  List<ChatSession> _mockSessions = [];
  ChatSession? lastSavedSession;

  void setMockSessions(List<ChatSession> sessions) {
    _mockSessions = sessions;
  }

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }

  @override
  ChatSession? getChatSession(String id) {
    try {
      return _mockSessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    lastSavedSession = session;
    // update mockSessions
    final index = _mockSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
        _mockSessions[index] = session;
    }
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // no-op
  }
}

void main() {
    group('StorageService Files', () {
        late TestStorageService storageService;
        late ChatSession session;
        late ChatMessage messageWithAttachment;
        late TextFileAttachment attachment;

        setUp(() {
            storageService = TestStorageService();
            attachment = TextFileAttachment(
                name: 'test.txt',
                content: 'hello',
                sizeBytes: 5,
                mimeType: 'text/plain',
            );
            messageWithAttachment = ChatMessage(
                role: 'user',
                content: 'See file',
                timestamp: DateTime.now(),
                attachments: [attachment],
            );
            session = ChatSession(
                id: '1',
                title: 'Test Session',
                model: 'llama3',
                messages: [messageWithAttachment],
                createdAt: DateTime.now(),
            );
            storageService.setMockSessions([session]);
        });

        test('TextFileAttachment equality', () {
            final a1 = TextFileAttachment(name: 'a', content: 'b', sizeBytes: 1, mimeType: 'text/plain');
            final a2 = TextFileAttachment(name: 'a', content: 'b', sizeBytes: 1, mimeType: 'text/plain');
            expect(a1 == a2, true);
        });

        test('getAllAttachments returns attachments', () {
            final files = storageService.getAllAttachments();
            expect(files.length, 1);
            expect(files.first.attachment.name, 'test.txt');
            expect(files.first.chatId, '1');
        });

        test('deleteAttachment removes attachment', () async {
            await storageService.deleteAttachment('1', messageWithAttachment, attachment);

            expect(storageService.lastSavedSession, isNotNull);
            final savedSession = storageService.lastSavedSession!;

            expect(savedSession.messages.first.attachments, isNull);
        });
    });
}
