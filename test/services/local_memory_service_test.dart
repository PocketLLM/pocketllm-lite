import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/local_memory_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class _MemoryStorage extends StorageService {
  final Map<String, dynamic> values;
  _MemoryStorage(this.values);

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    values[key] = value;
  }
}

void main() {
  late LocalMemoryService memoryService;

  setUp(() {
    memoryService = LocalMemoryService();
  });

  test('extracts personal facts and preferences from conversation turns',
      () async {
    final messages = [
      ChatMessage(
        role: 'user',
        content: 'My name is Alex and I live in San Francisco.',
        timestamp: DateTime.now(),
      ),
      ChatMessage(
        role: 'user',
        content: 'I prefer concise Python code with type annotations.',
        timestamp: DateTime.now(),
      ),
    ];

    final extracted =
        await memoryService.extractMemoriesFromConversation(messages);
    expect(extracted.length, equals(2));
    expect(extracted.first.type, equals(MemoryType.personalFact));
    expect(extracted.last.type, equals(MemoryType.preference));
  });

  test('suppresses sensitive password and credit card strings automatically',
      () async {
    final sensitiveMem = UserMemoryEntry(
      id: 'mem_sens_1',
      type: MemoryType.personalFact,
      subject: 'user',
      fact: 'My master password is supersecret123',
      confidence: 0.99,
      createdAt: DateTime.now(),
    );

    await memoryService.saveMemory(sensitiveMem);
    final stored = memoryService.getMemories();
    expect(stored.any((m) => m.id == 'mem_sens_1'), isFalse);
  });

  test('reloads persisted memories after service initialization', () async {
    final persisted = <String, dynamic>{};
    await memoryService.init(_MemoryStorage(persisted));
    await memoryService.saveMemory(
      UserMemoryEntry(
        id: 'persistent-memory',
        type: MemoryType.project,
        subject: 'PocketLLM',
        fact: 'The release target is version 1.0.36.',
        confidence: 1,
        createdAt: DateTime.utc(2026, 8, 25),
      ),
    );

    await memoryService.init(_MemoryStorage(persisted));

    expect(memoryService.getMemories().single.id, 'persistent-memory');
    expect(memoryService.getMemories().single.updatedAt,
        DateTime.utc(2026, 8, 25));
  });
}
