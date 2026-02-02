import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/media/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  @override
  List<MediaItem> getAllImages() {
    return [
      MediaItem(
        base64Content: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', // 1x1 red pixel
        chatId: '1',
        timestamp: DateTime.now(),
      ),
    ];
  }
}

class MockStorageServiceEmpty extends Fake implements StorageService {
  @override
  List<MediaItem> getAllImages() {
    return [];
  }
}

void main() {
  testWidgets('MediaGalleryScreen renders grid items', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: const MediaGalleryScreen(),
        ),
      ),
    );

    // Initial load
    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Media Gallery'), findsOneWidget);

    // Verify Grid Item
    expect(find.byType(Image), findsOneWidget);
    // There is one Hero widget wrapping the container which wraps the image
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('MediaGalleryScreen shows empty state', (WidgetTester tester) async {
    final mockStorage = MockStorageServiceEmpty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: const MediaGalleryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No images found in chats'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
