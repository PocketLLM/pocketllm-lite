import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  @override
  String? getDraft(String chatId) {
    return null;
  }

  @override
  Future<void> saveDraft(String chatId, String draft) async {}

  @override
  Future<void> deleteDraft(String chatId) async {}

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}
}

void main() {
  testWidgets('ChatInput has maxLength set to AppConstants.maxInputLength', (WidgetTester tester) async {
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

    // Find the TextField
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Verify maxLength property
    final TextField textField = tester.widget(textFieldFinder);
    expect(textField.maxLength, AppConstants.maxInputLength);

    // Verify buildCounter is set (to hidden)
    expect(textField.buildCounter, isNotNull);

    final counter = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 0,
      isFocused: false,
      maxLength: 100
    );
    expect(counter, isNull);
  });

  testWidgets('ChatInput shows Add Attachment button', (WidgetTester tester) async {
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

    // Find the Add Attachment button by Tooltip
    final addButtonFinder = find.byTooltip('Add Attachment');
    expect(addButtonFinder, findsOneWidget);

    // Tap it to ensure it doesn't crash (opens bottom sheet)
    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();

    // Verify BottomSheet content
    expect(find.text('Attach'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Document / Code'), findsOneWidget);
  });
}
