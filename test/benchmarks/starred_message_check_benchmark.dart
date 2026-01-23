import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/starred_message.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('Benchmark: isMessageStarred performance', () {
    // Setup
    const int starredCount = 100;
    const int checkCount = 1000;

    // Generate starred messages
    final List<StarredMessage> starredMessages = List.generate(starredCount, (index) {
      final msg = ChatMessage(
        role: index % 2 == 0 ? 'user' : 'assistant',
        content: 'Message content $index ' * 10, // Some length
        timestamp: DateTime.now().subtract(Duration(minutes: index)),
      );
      return StarredMessage(
        id: const Uuid().v4(),
        chatId: 'chat_$index',
        message: msg,
        starredAt: DateTime.now(),
      );
    });

    // Simulate raw Hive data (List<dynamic> of Maps)
    final List<dynamic> rawHiveData = starredMessages.map((m) => m.toJson()).toList();

    // Generate messages to check (mix of starred and not starred)
    final List<ChatMessage> messagesToCheck = List.generate(checkCount, (index) {
      if (index % 10 == 0) {
        // 10% are starred
        return starredMessages[index % starredCount].message;
      } else {
        // 90% are new/not starred
        return ChatMessage(
          role: 'assistant',
          content: 'Streaming content $index ' * 5,
          timestamp: DateTime.now(),
        );
      }
    });

    print('Benchmark: Checking $checkCount messages against $starredCount starred messages');

    // ---------------------------------------------------------
    // Approach 1: Naive (Current) - Deserialize and Iterate
    // ---------------------------------------------------------

    bool isMessageStarredNaive(ChatMessage message, List<dynamic> rawData) {
      final starred = rawData
          .map((e) => StarredMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return starred.any((s) => s.message == message);
    }

    final stopwatchNaive = Stopwatch()..start();
    for (final msg in messagesToCheck) {
      isMessageStarredNaive(msg, rawHiveData);
    }
    stopwatchNaive.stop();
    print('Naive Approach (Deserialize & Iterate): ${stopwatchNaive.elapsedMilliseconds}ms');

    // ---------------------------------------------------------
    // Approach 2: Optimized - Cached Set
    // ---------------------------------------------------------

    // Pre-build cache (simulating service init)
    final Set<ChatMessage> cachedSet = starredMessages.map((s) => s.message).toSet();

    bool isMessageStarredOptimized(ChatMessage message, Set<ChatMessage> cache) {
      return cache.contains(message);
    }

    final stopwatchOpt = Stopwatch()..start();
    for (final msg in messagesToCheck) {
      isMessageStarredOptimized(msg, cachedSet);
    }
    stopwatchOpt.stop();
    print('Optimized Approach (Cached Set): ${stopwatchOpt.elapsedMilliseconds}ms');

    if (stopwatchOpt.elapsedMilliseconds > 0) {
       final improvement = stopwatchNaive.elapsedMilliseconds / stopwatchOpt.elapsedMilliseconds;
       print('Improvement: ${improvement.toStringAsFixed(1)}x');
    } else {
       print('Improvement: Infinite (Optimized took 0ms)');
    }
  });
}
