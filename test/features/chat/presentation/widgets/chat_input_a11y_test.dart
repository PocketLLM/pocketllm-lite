import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart'; // For ChatMessage type if needed, but not used directly here
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';

class MockBox extends Mock implements Box {}

// Mock StorageService
class MockStorageService extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  @override
  String? getDraft(String key) => null;

  @override
  Future<void> saveDraft(String key, String content) async {}

  @override
  Future<void> deleteDraft(String key) async {}

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  ValueNotifier<Box> get starredMessagesListenable => ValueNotifier(MockBox());
}

// Mock Image Picker
class MockImagePicker extends ImagePickerPlatform {
  @override
  Future<PickedFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    return PickedFile('');
  }

  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
      return XFile.fromData(Uint8List.fromList([0, 1, 2, 3]), name: 'test.png');
  }

  @override
  Future<XFile?> getImageFromSource({
      required ImageSource source,
      ImagePickerOptions? options,
  }) async {
      return XFile.fromData(Uint8List.fromList([0, 1, 2, 3]), name: 'test.png');
  }
}

void main() {
  setUp(() {
    ImagePickerPlatform.instance = MockImagePicker();
  });

  testWidgets('ChatInput image attachment has correct accessibility labels', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInput(),
          ),
        ),
      ),
    );

    // 1. Open the image picker sheet
    final addImageButton = find.byTooltip('Add Image');
    expect(addImageButton, findsOneWidget);
    await tester.tap(addImageButton);
    await tester.pumpAndSettle();

    // 2. Select Gallery (which triggers our mock)
    final galleryOption = find.text('Gallery');
    expect(galleryOption, findsOneWidget);
    await tester.tap(galleryOption);
    await tester.pumpAndSettle();

    // 3. Verify image is displayed (just finding the Close icon implies an image is there)
    expect(find.byIcon(Icons.close), findsOneWidget);

    // 4. Check Semantics
    // Use widget predicate to reliably find the Semantics widget by its label property
    final imageSemantics = find.byWidgetPredicate((widget) =>
      widget is Semantics && widget.properties.label == 'Attached image 1 of 1'
    );
    expect(imageSemantics, findsOneWidget, reason: 'Image should have "Attached image 1 of 1" semantic label');

    // 5. Check Remove Button Tooltip
    final removeButton = find.byTooltip('Remove image 1 of 1');
    expect(removeButton, findsOneWidget, reason: 'Remove button should have "Remove image 1 of 1" tooltip');
  });
}
