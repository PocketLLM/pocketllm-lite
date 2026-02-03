import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/features/media/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:flutter/foundation.dart';

// Fake Box to satisfy ValueListenable<Box<ChatSession>>
class FakeBox<T> extends Fake implements Box<T> {}

class MockStorageService extends Fake implements StorageService {
  final List<ChatSession> _sessions;

  MockStorageService(this._sessions);

  @override
  ValueListenable<Box<ChatSession>> get chatBoxListenable {
    return ValueNotifier(FakeBox<ChatSession>());
  }

  @override
  List<ChatSession> getChatSessions() {
    return _sessions;
  }
}

void main() {
  testWidgets('MediaGalleryScreen displays images with semantics', (WidgetTester tester) async {
    // Setup data
    final timestamp = DateTime(2023, 10, 27, 10, 0);
    // 1x1 transparent pixel base64
    const base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

    final message = ChatMessage(
      role: 'assistant',
      content: 'Here is an image',
      timestamp: timestamp,
      images: [base64Image],
    );

    final session = ChatSession(
      id: 'chat1',
      title: 'Test Chat',
      model: 'test-model',
      messages: [message],
      createdAt: timestamp,
    );

    final mockStorage = MockStorageService([session]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: const MaterialApp(
          home: MediaGalleryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify image is displayed (by finding a ClipRRect which wraps it)
    expect(find.byType(ClipRRect), findsOneWidget);

    // Expect the semantic label to exist now
    // "Image from Test Chat, sent on Oct 27, 2023 10:00 AM"
    // Using regex to match the core parts
    final semanticFinder = find.bySemanticsLabel(RegExp(r'Image from Test Chat.*Oct 27, 2023'));
    expect(semanticFinder, findsOneWidget);
  });
}
