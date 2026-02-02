import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/prompt_enhancer_provider.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  final Map<String, dynamic> _settings = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }

  void setSetting(String key, dynamic value) {
    _settings[key] = value;
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  String? getDraft(String key) => null;

  @override
  Future<void> saveDraft(String key, String draft) async {}
}

void main() {
  testWidgets('ChatInput has maxLength set and shows dynamic counter', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          promptEnhancerProvider.overrideWith(PromptEnhancerNotifier.new),
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

    // Verify buildCounter is set
    expect(textField.buildCounter, isNotNull);

    // Test: Counter hidden when low count
    final counterHidden = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 10,
      isFocused: false,
      maxLength: 100
    );
    expect(counterHidden, isNull);

    // Test: Counter visible when high count (>80%)
    final counterVisible = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 81,
      isFocused: false,
      maxLength: 100
    );
    expect(counterVisible, isNotNull);
    expect((counterVisible as Semantics).child, isA<Text>());

    // Test: Counter is red when full
     final counterFull = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 100,
      isFocused: false,
      maxLength: 100
    );
    final textWidget = (counterFull as Semantics).child as Text;
    expect(textWidget.style?.color, Colors.red);
  });

  testWidgets('Prompt Enhancer button is always visible', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    // Ensure no model is selected
    mockStorage.setSetting(AppConstants.promptEnhancerModelKey, null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          promptEnhancerProvider.overrideWith(PromptEnhancerNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInput(),
          ),
        ),
      ),
    );

    // Find the Enhance Prompt button (it's an auto_awesome icon)
    final enhanceIconFinder = find.byIcon(Icons.auto_awesome);
    expect(enhanceIconFinder, findsOneWidget);

    // Check Semantics label
    // Use find.bySemanticsLabel to ensure we find the correct Semantics node
    // regardless of nesting (e.g. Tooltip/InkWell might add their own Semantics)
    expect(find.bySemanticsLabel(RegExp(r'Setup Required')), findsOneWidget);
  });

  testWidgets('Tapping Prompt Enhancer without model shows SnackBar even if input empty', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    mockStorage.setSetting(AppConstants.promptEnhancerModelKey, null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          promptEnhancerProvider.overrideWith(PromptEnhancerNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInput(),
          ),
        ),
      ),
    );

    // Find the Enhance Prompt button
    final enhanceIconFinder = find.byIcon(Icons.auto_awesome);

    // Tap it
    await tester.tap(enhanceIconFinder);
    await tester.pump(); // Start animation
    await tester.pump(const Duration(seconds: 1)); // Finish animation

    // Expect SnackBar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Select a Prompt Enhancer model in Settings first.'), findsOneWidget);
  });
}
