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

  test('accepts only structured extractor candidates from user turns',
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

    final extracted = await memoryService.extractMemoriesFromConversation(
      messages,
      extractor: (_) async => const [
        ExtractedMemoryCandidate(
          key: 'user_name',
          type: MemoryType.personalFact,
          subject: 'user',
          fact: 'The user\'s name is Alex.',
          confidence: 0.98,
        ),
        ExtractedMemoryCandidate(
          key: 'preferred_code_style',
          type: MemoryType.preference,
          subject: 'user',
          fact: 'The user prefers concise Python with type annotations.',
          confidence: 0.94,
        ),
      ],
    );
    expect(extracted.length, equals(2));
    expect(extracted.first.type, equals(MemoryType.personalFact));
    expect(extracted.last.type, equals(MemoryType.preference));
  });

  test('a newer value supersedes a contradictory memory with the same key',
      () async {
    final persisted = <String, dynamic>{};
    await memoryService.init(_MemoryStorage(persisted));
    await memoryService.saveMemory(
      UserMemoryEntry(
        id: 'old-city',
        type: MemoryType.personalFact,
        subject: 'user',
        fact: 'The user lives in Berlin.',
        confidence: 0.95,
        createdAt: DateTime.utc(2026, 1, 1),
        memoryKey: 'home_city',
      ),
    );
    await memoryService.saveMemory(
      UserMemoryEntry(
        id: 'new-city',
        type: MemoryType.personalFact,
        subject: 'user',
        fact: 'The user lives in Munich.',
        confidence: 0.96,
        createdAt: DateTime.utc(2026, 8, 25),
        memoryKey: 'home_city',
      ),
    );

    expect(memoryService.getMemories().single.id, 'new-city');
    final history = memoryService.getMemories(includeSuperseded: true);
    expect(history, hasLength(2));
    expect(history.first.supersededById, 'new-city');
    expect(history.first.enabled, isFalse);
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

  test('merges semantically duplicate memories when real embeddings match',
      () async {
    await memoryService.init(_MemoryStorage({}));
    await memoryService.saveMemory(
      UserMemoryEntry(
        id: 'style-a',
        type: MemoryType.preference,
        subject: 'user',
        fact: 'The user likes short answers.',
        confidence: 0.9,
        createdAt: DateTime.utc(2026),
        embedding: const [1, 0],
        memoryKey: 'short_answers',
      ),
    );
    await memoryService.saveMemory(
      UserMemoryEntry(
        id: 'style-b',
        type: MemoryType.preference,
        subject: 'user',
        fact: 'The user prefers concise responses.',
        confidence: 0.95,
        createdAt: DateTime.utc(2026, 2),
        embedding: const [0.99, 0.01],
        memoryKey: 'concise_responses',
      ),
    );

    final memories = memoryService.getMemories();
    expect(memories, hasLength(1));
    expect(memories.single.id, 'style-a');
    expect(memories.single.fact, contains('concise'));
    expect(memories.single.confidence, 0.95);
  });
}
