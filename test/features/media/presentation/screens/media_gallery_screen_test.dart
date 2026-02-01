import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';
import 'package:pocketllm_lite/features/media/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<MediaItem> _mockImages;
  MockStorageService(this._mockImages);

  @override
  List<MediaItem> getAllImages() => _mockImages;
}

void main() {
  testWidgets('MediaGalleryScreen displays images', (WidgetTester tester) async {
    final now = DateTime.now();
    final images = [
      MediaItem(
        chatId: '1',
        messageId: 'm1',
        imagePath: 'SGVsbG8=', // Base64 "Hello"
        timestamp: now,
        chatTitle: 'Chat 1',
      ),
      MediaItem(
        chatId: '2',
        messageId: 'm2',
        imagePath: 'V29ybGQ=', // Base64 "World"
        timestamp: now.subtract(const Duration(days: 1)),
        chatTitle: 'Chat 2',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService(images)),
        ],
        child: const MaterialApp(
          home: MediaGalleryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle(); // Wait for Future

    // Verify app bar title
    expect(find.text('Media Gallery'), findsOneWidget);
    expect(find.text('2 images'), findsOneWidget);

    // Verify date headers
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);

    // Verify grid items (Images)
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('MediaGalleryScreen shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService([])),
        ],
        child: const MaterialApp(
          home: MediaGalleryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No images found'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
