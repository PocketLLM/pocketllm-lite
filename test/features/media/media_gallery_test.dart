import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Create a subclass to test getAllImages without Hive
class TestStorageService extends StorageService {
  final List<ChatSession> _sessions;

  TestStorageService(this._sessions);

  @override
  List<ChatSession> getChatSessions() {
    return _sessions;
  }
}

void main() {
  test('getAllImages extracts and sorts images from sessions', () {
    final now = DateTime.now();
    final session1 = ChatSession(
      id: 's1',
      title: 'Session 1',
      model: 'model',
      createdAt: now,
      messages: [
        ChatMessage(
          role: 'user',
          content: 'msg1',
          timestamp: now.subtract(const Duration(minutes: 10)),
          images: ['img1_1'],
        ),
        ChatMessage(
          role: 'assistant',
          content: 'msg2',
          timestamp: now.subtract(const Duration(minutes: 5)),
          images: ['img1_2', 'img1_3'],
        ),
      ],
    );

    final session2 = ChatSession(
      id: 's2',
      title: 'Session 2',
      model: 'model',
      createdAt: now.subtract(const Duration(days: 1)),
      messages: [
        ChatMessage(
          role: 'user',
          content: 'msg3',
          timestamp: now.subtract(const Duration(days: 1)),
          images: ['img2_1'],
        ),
      ],
    );

    final service = TestStorageService([session1, session2]);
    final images = service.getAllImages();

    expect(images.length, 4);

    // Sort order: timestamp descending
    // img1_2, img1_3 (5 mins ago) > img1_1 (10 mins ago) > img2_1 (1 day ago)

    expect(images[0].base64Image, isIn(['img1_2', 'img1_3']));
    expect(images[1].base64Image, isIn(['img1_2', 'img1_3']));
    expect(images[2].base64Image, 'img1_1');
    expect(images[3].base64Image, 'img2_1');

    expect(images[0].chatId, 's1');
    expect(images[3].chatId, 's2');
  });
}
