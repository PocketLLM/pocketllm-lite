import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/message_template.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  List<MessageTemplate> _mockTemplates = [];
  final List<String> logs = [];

  @override
  List<MessageTemplate> getMessageTemplates() {
    // Return a copy to mimic reading from storage
    return List.from(_mockTemplates);
  }

  @override
  Future<void> saveTemplatesToBox(List<MessageTemplate> templates) async {
    _mockTemplates = templates;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add('$action: $details');
  }

  // Helper for test setup
  void setMockTemplates(List<MessageTemplate> templates) {
    _mockTemplates = templates;
  }
}

void main() {
  group('StorageService Templates CRUD', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('saveMessageTemplate adds new template', () async {
      final template = MessageTemplate(
        id: '1',
        title: 'Test',
        content: 'Hello',
      );

      await storageService.saveMessageTemplate(template);

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(templates.first.title, 'Test');
      expect(storageService.logs.last, contains('Template Created'));
    });

    test('saveMessageTemplate updates existing template', () async {
      final initial = MessageTemplate(
        id: '1',
        title: 'Initial',
        content: 'Content',
      );
      storageService.setMockTemplates([initial]);

      final updated = MessageTemplate(
        id: '1',
        title: 'Updated',
        content: 'New Content',
      );

      await storageService.saveMessageTemplate(updated);

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(templates.first.title, 'Updated');
      expect(templates.first.content, 'New Content');
      expect(storageService.logs.last, contains('Template Updated'));
    });

    test('deleteMessageTemplate removes template', () async {
      final t1 = MessageTemplate(id: '1', title: 'T1', content: 'C1');
      final t2 = MessageTemplate(id: '2', title: 'T2', content: 'C2');
      storageService.setMockTemplates([t1, t2]);

      await storageService.deleteMessageTemplate('1');

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(templates.first.id, '2');
      expect(storageService.logs.last, contains('Template Deleted'));
    });

    test('deleteMessageTemplate does nothing if id not found', () async {
      final t1 = MessageTemplate(id: '1', title: 'T1', content: 'C1');
      storageService.setMockTemplates([t1]);

      await storageService.deleteMessageTemplate('999');

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(storageService.logs.isEmpty, true);
    });
  });
}
