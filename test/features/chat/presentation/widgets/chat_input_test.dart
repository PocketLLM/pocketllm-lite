import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/services/ollama_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';

class MockOllamaService extends Fake implements OllamaService {
  @override
  Future<bool> checkConnection() async => true;
}

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
    'Prompt Enhancer button is visible and shows setup tooltip when not configured',
    (WidgetTester tester) async {
      final mockStorage = MockStorageService();
      // Default mockStorage.getSetting returns null, so no model selected.

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatInput())),
        ),
      );

      // Verify button exists (it used to be hidden if not configured)
      final enhancerIcon = find.byIcon(Icons.auto_awesome);
      expect(enhancerIcon, findsOneWidget);

      // Verify Tooltip message
      final tooltipFinder = find.ancestor(
        of: enhancerIcon,
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, 'Setup Prompt Enhancer');
    },
  );

  testWidgets(
    'Tapping unconfigured Prompt Enhancer button shows setup instructions via SnackBar',
    (WidgetTester tester) async {
      final mockStorage = MockStorageService();
      // Default settings return null, so no model selected.

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            ollamaServiceProvider.overrideWithValue(MockOllamaService()),
            usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatInput())),
        ),
      );

      // Enter some text so the button does something (empty text returns early)
      await tester.enterText(find.byType(TextField), 'Help me write a poem');
      await tester.pump();

      // Tap the enhancer button
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      // Expect SnackBar with instructions
      expect(
        find.text('Select a Prompt Enhancer model in Settings first.'),
        findsOneWidget,
      );
      expect(find.text('Settings'), findsOneWidget); // Action button
    },
  );
}
