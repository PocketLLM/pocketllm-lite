import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/media_item.dart';
import 'package:pocketllm_lite/features/chat/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock classes
class FakeStorageService extends Fake implements StorageService {
  @override
  List<MediaItem> getAllImages() {
    return [];
  }
}

// Minimal Base64 image for testing
const String kTransparentImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  testWidgets('MediaGalleryScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          galleryImagesProvider.overrideWith((ref) async => []),
          storageServiceProvider.overrideWithValue(FakeStorageService()),
        ],
        child: const MaterialApp(home: MediaGalleryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No images found in your chats.'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('MediaGalleryScreen shows grid of images', (tester) async {
    final now = DateTime.now();
    final items = [
      MediaItem(
        chatId: '1',
        messageTimestamp: now,
        base64Image: kTransparentImageBase64,
        index: 0,
      ),
      MediaItem(
        chatId: '2',
        messageTimestamp: now,
        base64Image: kTransparentImageBase64,
        index: 0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          galleryImagesProvider.overrideWith((ref) async => items),
          storageServiceProvider.overrideWithValue(FakeStorageService()),
        ],
        child: const MaterialApp(home: MediaGalleryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Use find.byType(Image) or look for specific widgets
    // Image.memory creates an Image widget
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byType(GridView), findsOneWidget);
  });
}
