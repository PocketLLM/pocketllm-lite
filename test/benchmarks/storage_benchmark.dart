import 'dart:io';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:hive/hive.dart';
import 'package:pocket_llm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocket_llm_lite/features/chat/domain/models/chat_session.dart';

// Mocks
class MockChatMessage extends ChatMessage {
  MockChatMessage({
    required super.id,
    required super.role,
    required super.content,
    required super.timestamp,
  });
}

class StorageBenchmark extends BenchmarkBase {
  StorageBenchmark() : super('StorageBenchmark');

  late Box<ChatSession> _chatBox;
  final int sessionCount = 500;
  final int messagesPerSession = 50;
  Directory? tempDir;

  @override
  void setup() {
    // We cannot easily run async setup in BenchmarkBase synchronously.
    // However, we can use a separate method to prepare data.
  }

  Future<void> prepare() async {
    tempDir = await Directory.systemTemp.createTemp('hive_benchmark');
    Hive.init(tempDir!.path);
    if (!Hive.isAdapterRegistered(1)) {
       Hive.registerAdapter(ChatSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(ChatMessageAdapter());
    }

    _chatBox = await Hive.openBox<ChatSession>('benchmark_chats');

    // Populate data
    final sessions = <ChatSession>[];
    for (int i = 0; i < sessionCount; i++) {
      final messages = List.generate(messagesPerSession, (j) => ChatMessage(
        id: 'msg_$j',
        role: j % 2 == 0 ? 'user' : 'assistant',
        content: 'This is message number $j in session $i. ' * 10, // Some length
        timestamp: DateTime.now(),
      ));

      sessions.add(ChatSession(
        id: 'session_$i',
        title: 'Session $i',
        model: 'llama3',
        messages: messages,
        createdAt: DateTime.now().subtract(Duration(minutes: i)),
      ));
    }

    // Batch put
    final map = {for (var s in sessions) s.id: s};
    await _chatBox.putAll(map);
    await _chatBox.close();
  }

  Future<void> runBenchmark() async {
    // Measure opening and sorting
    _chatBox = await Hive.openBox<ChatSession>('benchmark_chats');

    final stopwatch = Stopwatch()..start();

    final sessions = _chatBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    stopwatch.stop();
    print('Benchmark: Loaded and sorted ${sessions.length} sessions in ${stopwatch.elapsedMilliseconds}ms');

    await _chatBox.close();
  }

  @override
  void teardown() {
    tempDir?.deleteSync(recursive: true);
  }
}

Future<void> main() async {
  final benchmark = StorageBenchmark();
  await benchmark.prepare();
  await benchmark.runBenchmark();
  benchmark.teardown();
}
