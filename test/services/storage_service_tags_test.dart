import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  Map<String, List<String>> _mockTags = {};

  void setMockTags(Map<String, List<String>> tags) {
    _mockTags = tags;
  }

  @override
  Map<String, List<String>> getChatTagsMap() {
    return _mockTags;
  }

  @override
  Future<void> saveChatTags(Map<String, List<String>> map) async {
    _mockTags = map;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for tests
  }
}

void main() {
  group('StorageService Tag Management', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
      // Need to use deep copies if logic modifies in place
      storageService.setMockTags({
        'chat1': ['Work', 'Important'],
        'chat2': ['Work', 'Flutter'],
        'chat3': ['Personal'],
      });
    });

    test('renameTag renames tag in all chats', () async {
      await storageService.renameTag('Work', 'Job');

      final tags1 = storageService.getTagsForChat('chat1');
      final tags2 = storageService.getTagsForChat('chat2');
      final tags3 = storageService.getTagsForChat('chat3');

      expect(tags1, contains('Job'));
      expect(tags1, isNot(contains('Work')));
      expect(tags1, contains('Important'));

      expect(tags2, contains('Job'));
      expect(tags2, isNot(contains('Work')));
      expect(tags2, contains('Flutter'));

      expect(tags3, contains('Personal'));
      expect(tags3, isNot(contains('Job')));
    });

    test('renameTag merges if target tag exists', () async {
      // chat1 has 'Work' and 'Important'. Rename 'Work' to 'Important'.
      // chat1 should end up with just 'Important' (no duplicates).
      await storageService.renameTag('Work', 'Important');

      final tags1 = storageService.getTagsForChat('chat1');
      expect(tags1.length, 1);
      expect(tags1.first, 'Important');
    });

    test('deleteTag removes tag from all chats', () async {
      await storageService.deleteTag('Work');

      final tags1 = storageService.getTagsForChat('chat1');
      final tags2 = storageService.getTagsForChat('chat2');

      expect(tags1, isNot(contains('Work')));
      expect(tags1, contains('Important'));

      expect(tags2, isNot(contains('Work')));
      expect(tags2, contains('Flutter'));
    });

    test('deleteTag cleans up empty chats', () async {
       // chat3 has only 'Personal'
       await storageService.deleteTag('Personal');

       // Accessing internal map to check key removal
       final map = storageService.getChatTagsMap();
       expect(map.containsKey('chat3'), false);
    });
  });
}
