import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';
import 'package:pocketllm_lite/features/media/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Mock StorageService
class MockStorageService extends Mock implements StorageService {
  @override
  List<MediaItem> getAllImages() {
    return super.noSuchMethod(
      Invocation.method(#getAllImages, []),
      returnValue: <MediaItem>[],
      returnValueForMissingStub: <MediaItem>[],
    );
  }

  @override
  ValueListenable<Box<ChatSession>> get chatBoxListenable =>
      ValueNotifier<Box<ChatSession>>(MockBox());
}

// Mock Box for listenable
class MockBox extends Mock implements Box<ChatSession> {}

void main() {
  testWidgets('MediaGalleryScreen shows empty state when no images', (tester) async {
    final mockStorage = MockStorageService();
    when(mockStorage.getAllImages()).thenReturn([]);

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

    // Pump to let the ValueListenableBuilder build
    await tester.pump();

    expect(find.text('No images found in your chats'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
