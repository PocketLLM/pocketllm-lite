import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  List<Map<String, String>> _mockTemplates = [];
  final List<Map<String, dynamic>> _mockLogs = [];

  void setMockTemplates(List<Map<String, String>> templates) {
    _mockTemplates = List.from(templates); // Make a copy
  }

  @override
  List<Map<String, String>> readTemplatesFromBox() {
    return _mockTemplates;
  }

  @override
  Future<void> writeTemplatesToBox(List<Map<String, String>> templates) async {
    _mockTemplates = templates;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    _mockLogs.add({
      'action': action,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> get mockLogs => _mockLogs;
}

void main() {
  group('StorageService Template Management', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('Create template generates ID if missing', () async {
      // Use a mutable map
      final template = <String, String>{
        'title': 'New Template',
        'content': 'Hello',
      };

      await storageService.saveMessageTemplate(template);

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(templates.first['title'], 'New Template');
      expect(templates.first['id'], isNotNull);
      expect(templates.first['id'], isNotEmpty);

      expect(storageService.mockLogs.length, 1);
      expect(storageService.mockLogs.first['action'], 'Template Created');
    });

    test('Update existing template', () async {
      final initial = {
        'id': '123',
        'title': 'Original',
        'content': 'Content',
      };
      storageService.setMockTemplates([initial]);

      final updated = {
        'id': '123',
        'title': 'Updated',
        'content': 'New Content',
      };

      await storageService.saveMessageTemplate(updated);

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(templates.first['title'], 'Updated');
      expect(templates.first['content'], 'New Content');

      expect(storageService.mockLogs.length, 1);
      expect(storageService.mockLogs.first['action'], 'Template Updated');
    });

    test('Delete template', () async {
      final t1 = {'id': '1', 'title': 'T1', 'content': 'C1'};
      final t2 = {'id': '2', 'title': 'T2', 'content': 'C2'};
      storageService.setMockTemplates([t1, t2]);

      await storageService.deleteMessageTemplate('1');

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(templates.first['id'], '2');

      expect(storageService.mockLogs.length, 1);
      expect(storageService.mockLogs.first['action'], 'Template Deleted');
    });

    test('Delete non-existent template does nothing', () async {
      final t1 = {'id': '1', 'title': 'T1', 'content': 'C1'};
      storageService.setMockTemplates([t1]);

      await storageService.deleteMessageTemplate('999');

      final templates = storageService.getMessageTemplates();
      expect(templates.length, 1);
      expect(storageService.mockLogs.isEmpty, true);
    });
  });
}
