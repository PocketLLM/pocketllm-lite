import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Since we cannot run real tests with Hive in this environment,
// we will verify the logic by creating a partial mock or subclass
// that overrides `getChatSessions` and tests `searchSessions`.

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
  group('StorageService Search & Filter Logic', () {
    late TestStorageService storageService;
    late List<ChatSession> sessions;

    setUp(() {
      storageService = TestStorageService();

      final now = DateTime.now();
      sessions = [
        ChatSession(
          id: '1',
          title: 'Flutter Help',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'How do I use Riverpod?',
              timestamp: now,
            ),
          ],
          createdAt: now, // Today
        ),
        ChatSession(
          id: '2',
          title: 'Cooking Recipes',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Pizza ingredients',
              timestamp: now,
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Flour, tomato sauce, cheese',
              timestamp: now,
            ),
          ],
          createdAt: now.subtract(const Duration(days: 2)), // 2 days ago
        ),
        ChatSession(
          id: '3',
          title: 'Flutter State Management',
          model: 'llama3',
          messages: [],
          createdAt: now.subtract(const Duration(days: 10)), // 10 days ago
        ),
        ChatSession(
          id: '4',
          title: 'Life Advice',
          model: 'gemma',
          messages: [],
          createdAt: now.subtract(const Duration(days: 40)), // 40 days ago
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('Search by query (case insensitive)', () {
      final results = storageService.searchSessions(query: 'flutter');
      expect(results.length, 2);
      expect(results.any((s) => s.id == '1'), true);
      expect(results.any((s) => s.id == '3'), true);
    });

    test('Search by query (no match)', () {
      final results = storageService.searchSessions(query: 'java');
      expect(results.isEmpty, true);
    });

    test('Search by message content', () {
      // "Riverpod" is in the message of "Flutter Help" (id: 1), but not in title.
      final results = storageService.searchSessions(query: 'Riverpod');
      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('Search by message content (assistant response)', () {
      // "cheese" is in the assistant response of "Cooking Recipes" (id: 2)
      final results = storageService.searchSessions(query: 'cheese');
      expect(results.length, 1);
      expect(results.first.id, '2');
    });

    test('Filter by Model', () {
      final results = storageService.searchSessions(model: 'llama3');
      expect(results.length, 2);
      expect(results.every((s) => s.model == 'llama3'), true);
    });

    test('Filter by Date (Last 7 days)', () {
      final fromDate = DateTime.now().subtract(const Duration(days: 7));
      final results = storageService.searchSessions(fromDate: fromDate);
      expect(results.length, 2); // Today and 2 days ago
      expect(results.any((s) => s.id == '1'), true);
      expect(results.any((s) => s.id == '2'), true);
    });

    test('Combined Filter (Query + Model)', () {
      final results = storageService.searchSessions(
        query: 'flutter',
        model: 'llama3',
      );
      expect(results.length, 2);
    });

    test('Combined Filter (Query + Date)', () {
      final fromDate = DateTime.now().subtract(const Duration(days: 7));
      // "Flutter Help" is today, "Flutter State" is 10 days ago.
      // So filtering "flutter" + "last 7 days" should only return "Flutter Help".
      final results = storageService.searchSessions(
        query: 'flutter',
        fromDate: fromDate,
      );
      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('Get Available Models', () {
      final models = storageService.getAvailableModels();
      expect(models.length, 3);
      expect(models.contains('llama3'), true);
      expect(models.contains('mistral'), true);
      expect(models.contains('gemma'), true);
    });
  });
}
