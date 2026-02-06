import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/text_file_attachment.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final List<ChatSession> sessions = [];

  @override
  Future<void> init() async {}

  @override
  List<ChatSession> getChatSessions() {
    return sessions;
  }

  @override
  ChatSession? getChatSession(String id) {
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> logActivity(String action, String details) async {}
}

void main() {
  group('StorageService File Attachments', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllTextAttachments retrieves attachments from all chats', () {
      final attachment1 = TextFileAttachment(
        name: 'test1.txt',
        content: 'content1',
        sizeBytes: 10,
        mimeType: 'text/plain',
      );
      final attachment2 = TextFileAttachment(
        name: 'test2.md',
        content: 'content2',
        sizeBytes: 20,
        mimeType: 'text/markdown',
      );

      final message1 = ChatMessage(
        role: 'user',
        content: 'msg1',
        timestamp: DateTime.now(),
        attachments: [attachment1],
      );

      final message2 = ChatMessage(
        role: 'assistant',
        content: 'msg2',
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
        attachments: [attachment2],
      );

      final session = ChatSession(
        id: 'session1',
        title: 'Test Session',
        model: 'test-model',
        messages: [message1, message2],
        createdAt: DateTime.now(),
      );

      storageService.sessions.add(session);

      final files = storageService.getAllTextAttachments();

      expect(files.length, 2);
      expect(files.any((f) => f.attachment == attachment1), isTrue);
      expect(files.any((f) => f.attachment == attachment2), isTrue);
      expect(files.first.chatId, 'session1');
    });

    test('deleteAttachment removes specific attachment', () async {
      final attachment1 = TextFileAttachment(
        name: 'to_delete.txt',
        content: 'delete me',
        sizeBytes: 10,
        mimeType: 'text/plain',
      );
      final attachment2 = TextFileAttachment(
        name: 'keep_me.txt',
        content: 'keep me',
        sizeBytes: 10,
        mimeType: 'text/plain',
      );

      final timestamp = DateTime.now();
      final message = ChatMessage(
        role: 'user',
        content: 'msg',
        timestamp: timestamp,
        attachments: [attachment1, attachment2],
      );

      final session = ChatSession(
        id: 'session1',
        title: 'Test Session',
        model: 'test-model',
        messages: [message],
        createdAt: DateTime.now(),
      );

      storageService.sessions.add(session);

      // Verify initial state
      expect(storageService.getAllTextAttachments().length, 2);

      // Delete attachment1
      await storageService.deleteAttachment('session1', timestamp, attachment1);

      // Verify updated state
      final files = storageService.getAllTextAttachments();
      expect(files.length, 1);
      expect(files.first.attachment.name, 'keep_me.txt');

      // Verify session updated in storage
      final updatedSession = storageService.getChatSession('session1');
      expect(updatedSession!.messages.first.attachments!.length, 1);
      expect(
        updatedSession.messages.first.attachments!.first.name,
        'keep_me.txt',
      );
    });

    test(
      'deleteAttachment handles message with single attachment correctly',
      () async {
        final attachment = TextFileAttachment(
          name: 'only.txt',
          content: 'only',
          sizeBytes: 10,
          mimeType: 'text/plain',
        );

        final timestamp = DateTime.now();
        final message = ChatMessage(
          role: 'user',
          content: 'msg',
          timestamp: timestamp,
          attachments: [attachment],
        );

        final session = ChatSession(
          id: 'session1',
          title: 'Test Session',
          model: 'test-model',
          messages: [message],
          createdAt: DateTime.now(),
        );

        storageService.sessions.add(session);

        await storageService.deleteAttachment(
          'session1',
          timestamp,
          attachment,
        );

        final updatedSession = storageService.getChatSession('session1');
        // Should be empty list or null depending on implementation.
        // My implementation sets it to [] if empty.
        expect(updatedSession!.messages.first.attachments, isEmpty);
      },
    );
  });
}
