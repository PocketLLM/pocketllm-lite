// ignore_for_file: avoid_print
import 'dart:collection';

class MockSession {
  final String id;
  final DateTime createdAt;
  final String content;

  MockSession(this.id, this.createdAt, this.content);

  MockSession copyWith({String? content}) {
    return MockSession(id, createdAt, content ?? this.content);
  }
}

void main() {
  // Setup
  final int sessionCount = 1000;
  final int updatesCount = 1000;

  // Generate initial data
  final List<MockSession> sourceData = List.generate(sessionCount, (index) {
    return MockSession(
      'session_$index',
      DateTime.now().subtract(Duration(minutes: index)), // decreasing dates
      'Initial content',
    );
  });

  // Randomize source order to simulate unsorted storage
  sourceData.shuffle();

  print(
    'Benchmark: Managing $sessionCount sessions with $updatesCount updates',
  );

  // ---------------------------------------------------------
  // Approach 1: Naive (Current) - Invalidate and Resort
  // ---------------------------------------------------------

  List<MockSession>? cachedSessionsNaive;

  // Getter simulates the service getter
  List<MockSession> getSessionsNaive(List<MockSession> storage) {
    if (cachedSessionsNaive != null) {
      return UnmodifiableListView(cachedSessionsNaive!);
    }
    // Simulate reading values and sorting
    cachedSessionsNaive = storage.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return UnmodifiableListView(cachedSessionsNaive!);
  }

  // Update simulates saving a session (invalidates cache)
  void updateSessionNaive(List<MockSession> storage, MockSession updated) {
    // Update underlying storage
    final index = storage.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      storage[index] = updated;
    }
    // Invalidate cache
    cachedSessionsNaive = null;
  }

  // Run Benchmark 1
  final stopwatchNaive = Stopwatch()..start();

  // Initial load
  getSessionsNaive(sourceData);

  for (int i = 0; i < updatesCount; i++) {
    // Pick a session to update (e.g., the 50th one)
    final targetId = 'session_${i % sessionCount}';
    final currentSession = sourceData.firstWhere((s) => s.id == targetId);
    final updatedSession = currentSession.copyWith(content: 'Updated $i');

    updateSessionNaive(sourceData, updatedSession);

    // Immediate access after update (typical UI pattern)
    getSessionsNaive(sourceData);
  }

  stopwatchNaive.stop();
  print(
    'Naive Approach (Invalidate & Resort): ${stopwatchNaive.elapsedMilliseconds}ms',
  );

  // ---------------------------------------------------------
  // Approach 2: Optimized - Smart Update
  // ---------------------------------------------------------

  List<MockSession>? cachedSessionsOpt;

  List<MockSession> getSessionsOpt(List<MockSession> storage) {
    if (cachedSessionsOpt != null) {
      return UnmodifiableListView(cachedSessionsOpt!);
    }
    // Initial sort still happens once
    cachedSessionsOpt = storage.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return UnmodifiableListView(cachedSessionsOpt!);
  }

  void updateSessionOpt(List<MockSession> storage, MockSession updated) {
    // Update underlying storage
    final index = storage.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      storage[index] = updated;
    }

    // Smart update cache
    if (cachedSessionsOpt != null) {
      final cacheIndex = cachedSessionsOpt!.indexWhere(
        (s) => s.id == updated.id,
      );
      if (cacheIndex != -1) {
        // Replace in place - O(1) assuming we found index (O(N) search)
        // Since list is array backed, search is O(N), replace is O(1).
        // Total O(N). Naive sort is O(N log N).
        cachedSessionsOpt![cacheIndex] = updated;
      } else {
        // Insert new (not handled in this bench for simplicity of comparison on updates)
        cachedSessionsOpt!.insert(0, updated);
        // If strict order needed, we might need to sort or find index, but here we test update.
      }
    }
  }

  // Reset source data copy for fair test
  final List<MockSession> sourceDataOpt = List.from(
    sourceData,
  ); // Shallow copy is enough as we replace objects

  // Run Benchmark 2
  final stopwatchOpt = Stopwatch()..start();

  // Initial load
  getSessionsOpt(sourceDataOpt);

  for (int i = 0; i < updatesCount; i++) {
    final targetId = 'session_${i % sessionCount}';
    final currentSession = sourceDataOpt.firstWhere((s) => s.id == targetId);
    final updatedSession = currentSession.copyWith(content: 'Updated $i');

    updateSessionOpt(sourceDataOpt, updatedSession);

    // Immediate access after update
    getSessionsOpt(sourceDataOpt);
  }

  stopwatchOpt.stop();
  print(
    'Optimized Approach (Smart Update): ${stopwatchOpt.elapsedMilliseconds}ms',
  );

  final improvement =
      stopwatchNaive.elapsedMilliseconds / stopwatchOpt.elapsedMilliseconds;
  print('Improvement: ${improvement.toStringAsFixed(1)}x');
}
