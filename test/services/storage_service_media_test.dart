import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final List<ChatSession> mockSessions;

  TestStorageService(this.mockSessions);

  @override
  List<ChatSession> getChatSessions() {
    return mockSessions;
  }
}

void main() {
  test('getAllImages returns correctly sorted images from sessions', () {
    final now = DateTime.now();
    final older = now.subtract(const Duration(days: 1));
    final oldest = now.subtract(const Duration(days: 2));

    final session1 = ChatSession(
      id: 's1',
      title: 'Session 1',
      model: 'model',
      createdAt: older,
      messages: [
        ChatMessage(
          role: 'user',
          content: 'msg1',
          timestamp: older,
          images: ['img1'],
        ),
      ],
    );

    final session2 = ChatSession(
      id: 's2',
      title: 'Session 2',
      model: 'model',
      createdAt: now,
      messages: [
        ChatMessage(
          role: 'user',
          content: 'msg2',
          timestamp: now,
          images: ['img2', 'img3'],
        ),
      ],
    );

    final session3 = ChatSession(
        id: 's3',
        title: 'Session 3',
        model: 'model',
        createdAt: oldest,
        messages: [
             ChatMessage(
              role: 'assistant',
              content: 'msg3',
              timestamp: oldest,
              images: [] // No images
             )
        ]
    );

    final storage = TestStorageService([session1, session2, session3]);
    final images = storage.getAllImages();

    expect(images.length, 3);

    // Sort order: newest first (session2 images (timestamp: now), then session1 image (timestamp: older))
    // Note: session2 has two images with SAME timestamp. Stability/Order inside message preserved?
    // The implementation loops i=0..length.

    expect(images[0].base64Content, 'img2');
    expect(images[0].chatId, 's2');

    expect(images[1].base64Content, 'img3');
    expect(images[1].chatId, 's2');

    expect(images[2].base64Content, 'img1');
    expect(images[2].chatId, 's1');
  });
}
