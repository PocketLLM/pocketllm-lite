import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Fake Box for mocking Hive listeners
class FakeBox<T> extends Fake implements Box<T> {
  @override
  bool get isOpen => true;
}

// Subclass ValueNotifier to expose notifyListeners
class MockBoxListenable extends ValueNotifier<Box> {
  MockBoxListenable() : super(FakeBox());

  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final MockBoxListenable _notifier = MockBoxListenable();
  final Set<ChatMessage> _starred = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _notifier;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starred.contains(message);
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  // Method to trigger update for testing
  void toggleStar(ChatMessage message) {
    if (_starred.contains(message)) {
      _starred.remove(message);
    } else {
      _starred.add(message);
    }
    // Notify listeners
    _notifier.notifyListeners();
  }
}

void main() {
  group('ChatBubble', () {
    late MockStorageService mockStorage;
    late ChatMessage testMessage;

    setUp(() {
      mockStorage = MockStorageService();
      testMessage = ChatMessage(
        role: 'user',
        content: 'Hello world',
        timestamp: DateTime.now(),
      );
    });

    testWidgets('renders content correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(message: testMessage),
            ),
          ),
        ),
      );

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('shows star icon when starred', (tester) async {
      // Star the message
      mockStorage.toggleStar(testMessage);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(message: testMessage),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('does not show star icon when not starred', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(message: testMessage),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('updates UI when star status changes', (tester) async {
       await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(message: testMessage),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsNothing);

      // Update star status
      mockStorage.toggleStar(testMessage);

      // Trigger rebuild
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });
}
