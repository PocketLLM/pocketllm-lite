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
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  String? getDraft(String chatId) => null;

  @override
  Future<void> saveDraft(String chatId, String draft) async {}

  @override
  Future<void> deleteDraft(String chatId) async {}
}

void main() {
  testWidgets('ChatInput has maxLength set to AppConstants.maxInputLength', (
    WidgetTester tester,
  ) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatInput())),
      ),
    );

    // Find the TextField
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Verify maxLength property
    final TextField textField = tester.widget(textFieldFinder);
    expect(textField.maxLength, AppConstants.maxInputLength);

    // Verify buildCounter is set (to hidden)
    // We can't easily execute the buildCounter to check return value without context,
    // but we can check it's not null.
    expect(textField.buildCounter, isNotNull);

    // To be sure, we can call it if we want, but checking isNotNull is likely enough
    // to verify the property was set.
    final counter = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 0,
      isFocused: false,
      maxLength: 100,
    );
    expect(counter, isNull);
  });

  testWidgets(
    'ChatInput shows character counter only when text is long',
    (WidgetTester tester) async {
      final mockStorage = MockStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatInput())),
        ),
      );

      // Find the TextField
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // 1. Enter short text (< 1000 chars)
      await tester.enterText(textFieldFinder, 'Short message');
      await tester.pumpAndSettle();

      // Verify counter is NOT visible
      // The counter text format is "$charCount/$maxLength"
      // maxLength is AppConstants.maxInputLength (50000)
      final shortCounterText =
          '${'Short message'.length}/${AppConstants.maxInputLength}';
      expect(find.text(shortCounterText), findsNothing);

      // 2. Enter long text (> 1000 chars)
      final longText = 'a' * 1001;
      await tester.enterText(textFieldFinder, longText);
      await tester.pumpAndSettle();

      // Verify counter IS visible
      final longCounterText = '${longText.length}/${AppConstants.maxInputLength}';
      expect(find.text(longCounterText), findsOneWidget);
    },
  );
}
