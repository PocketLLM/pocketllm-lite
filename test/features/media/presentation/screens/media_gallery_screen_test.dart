import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/media/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

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
  dynamic getSetting(String? key, {dynamic defaultValue}) {
      return defaultValue;
  }
}

void main() {
  testWidgets('MediaGalleryScreen renders images', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    // Valid 1x1 transparent GIF
    final item = MediaItem(id: '1', base64: 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', chatId: 'c1', timestamp: DateTime.now());

    when(mockStorage.getAllImages()).thenReturn([item]);

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

    // Initial load might show loader
    // The screen uses addPostFrameCallback which triggers after first frame.
    // pumpAndSettle should wait for it.

    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    // Find the image widget. Since it's inside Hero -> Container -> Image
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('MediaGalleryScreen shows empty state', (WidgetTester tester) async {
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

    await tester.pumpAndSettle();

    expect(find.text('No images found'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
