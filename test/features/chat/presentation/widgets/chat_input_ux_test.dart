import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';

// Mock StorageService with properly overridden methods
class MockStorageService extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    // Return null for prompt enhancer model to simulate "not configured" state
    if (key == AppConstants.promptEnhancerModelKey) return null;
    return defaultValue;
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  String? getDraft(String sessionId) => null;

  @override
  Future<void> saveDraft(String sessionId, String draft) async {}

  @override
  Future<void> deleteDraft(String sessionId) async {}
}

void main() {
  testWidgets('ChatInput UX: Enhance Prompt button visible even when not configured', (WidgetTester tester) async {
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

    // Verify the Enhance Prompt button is visible
    // It has Semantics label 'Enhance Prompt'
    final buttonFinder = find.bySemanticsLabel('Enhance Prompt');
    expect(buttonFinder, findsOneWidget);

    // Verify tooltip message implies configuration needed (discovery mode)
    final tooltipFinder = find.byTooltip('Configure Enhancer');
    expect(tooltipFinder, findsOneWidget);
  });

  testWidgets('ChatInput UX: Character counter logic works correctly', (WidgetTester tester) async {
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

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    final TextField textField = tester.widget(textFieldFinder);
    final buildCounter = textField.buildCounter;

    expect(buildCounter, isNotNull, reason: "buildCounter should be implemented");

    // Case 1: Below 80% threshold -> Should return null
    final resultLow = buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 50,
      maxLength: 100,
      isFocused: true,
    );
    expect(resultLow, isNull);

    // Case 2: Above 80% threshold -> Should return widget
    final resultHigh = buildCounter(
      tester.element(textFieldFinder),
      currentLength: 85,
      maxLength: 100,
      isFocused: true,
    );
    expect(resultHigh, isNotNull);
    expect(resultHigh, isA<Semantics>());

    final semantics = resultHigh as Semantics;
    // Semantics should not contain Text directly as child often, but let's check.
    // In our implementation: Semantics > Text
    expect(semantics.child, isA<Text>());
    final textWidget = semantics.child as Text;
    expect(textWidget.data, '85/100');
    expect(textWidget.style?.color, Colors.orange);

    // Case 3: At Limit -> Red color
    final resultLimit = buildCounter(
      tester.element(textFieldFinder),
      currentLength: 100,
      maxLength: 100,
      isFocused: true,
    );
    final textWidgetLimit = (resultLimit as Semantics).child as Text;
    expect(textWidgetLimit.data, '100/100');
    expect(textWidgetLimit.style?.color, Colors.red);
  });
}
