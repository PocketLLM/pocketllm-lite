import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/media_item.dart';
import 'package:pocketllm_lite/features/chat/presentation/screens/media_gallery_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class FakeStorageService extends Fake implements StorageService {
  @override
  List<MediaItem> getAllImages() {
    return [];
  }
}

void main() {
  testWidgets('MediaGalleryScreen renders correctly with empty list', (WidgetTester tester) async {
    final mockStorage = FakeStorageService();

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

    // Initial load might be async due to Future.microtask
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Media Gallery'), findsOneWidget);
    expect(find.text('No images found in chat history'), findsOneWidget);
  });
}
