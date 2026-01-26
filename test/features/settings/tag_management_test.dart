import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  Map<String, List<String>> _tags = {};

  @override
  Map<String, List<String>> getChatTagsMap() {
    return _tags;
  }

  @override
  Future<void> saveChatTagsMap(Map<String, List<String>> map) async {
    _tags = map;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }

  void setTags(Map<String, List<String>> tags) {
    _tags = tags;
  }
}

void main() {
  group('Tag Management Tests', () {
    late TestStorageService storage;

    setUp(() {
      storage = TestStorageService();
      storage.setTags({
        'chat1': ['work', 'important'],
        'chat2': ['work', 'todo'],
        'chat3': ['personal'],
      });
    });

    test('getTagsWithCounts returns correct counts', () {
      final counts = storage.getTagsWithCounts();
      expect(counts['work'], 2);
      expect(counts['important'], 1);
      expect(counts['todo'], 1);
      expect(counts['personal'], 1);
      expect(counts.length, 4);
    });

    test('renameTag updates all occurrences', () async {
      await storage.renameTag('work', 'job');

      final tags1 = storage.getTagsForChat('chat1');
      final tags2 = storage.getTagsForChat('chat2');

      expect(tags1.contains('work'), false);
      expect(tags1.contains('job'), true);
      expect(tags2.contains('work'), false);
      expect(tags2.contains('job'), true);

      // Ensure other tags remain
      expect(tags1.contains('important'), true);
    });

    test('renameTag handles duplicates (merging)', () async {
      // chat1 has 'work' and 'important'. Rename 'important' to 'work'.
      // Result should be ['work'] (no duplicate 'work').
      await storage.renameTag('important', 'work');

      final tags1 = storage.getTagsForChat('chat1');
      expect(tags1.length, 1);
      expect(tags1.first, 'work');
    });

    test('deleteTagGlobal removes tag from all chats', () async {
      await storage.deleteTagGlobal('work');

      final tags1 = storage.getTagsForChat('chat1');
      final tags2 = storage.getTagsForChat('chat2');

      expect(tags1.contains('work'), false);
      expect(tags1.contains('important'), true);
      expect(tags2.contains('work'), false);
      expect(tags2.contains('todo'), true);
    });

    test(
      'deleteTagGlobal removes chat entry if tag list becomes empty',
      () async {
        // chat3 only has 'personal'
        await storage.deleteTagGlobal('personal');

        final map = storage.getChatTagsMap();
        expect(map.containsKey('chat3'), false);
      },
    );
  });
}
