import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock subclass to avoid Hive dependencies
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
  group('StorageService Media Logic', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllImages returns all images sorted by date', () {
      final now = DateTime.now();

      final sessions = [
        ChatSession(
          id: '1',
          title: 'Chat with Image',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Here is an image',
              timestamp: now,
              images: ['base64_image_newest'],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat without Image',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Just text',
              timestamp: now.subtract(const Duration(minutes: 5)),
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        ChatSession(
          id: '3',
          title: 'Chat with Multiple Images',
          model: 'gemma',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Two images',
              timestamp: now.subtract(const Duration(hours: 1)),
              images: ['base64_image_older_1', 'base64_image_older_2'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      storageService.setMockSessions(sessions);

      final images = storageService.getAllImages();

      expect(images.length, 3);

      // First image should be the newest one
      expect(images[0].imageBase64, 'base64_image_newest');
      expect(images[0].chatId, '1');

      // Subsequent images
      expect(images.where((i) => i.imageBase64 == 'base64_image_older_1').isNotEmpty, true);
      expect(images.where((i) => i.imageBase64 == 'base64_image_older_2').isNotEmpty, true);

      // Verify sorting: Newest timestamp is first
      expect(images[0].timestamp.isAfter(images[1].timestamp), true);
    });

    test('getAllImages returns empty list when no images present', () {
      storageService.setMockSessions([
          ChatSession(
            id: '4',
            title: 'No Images',
            model: 'llama3',
            messages: [
              ChatMessage(
                role: 'user',
                content: 'text',
                timestamp: DateTime.now()
              )
            ],
            createdAt: DateTime.now()
          )
      ]);
      final images = storageService.getAllImages();
      expect(images.isEmpty, true);
    });
  });
}
