import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/connection_status_provider.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  final Map<String, String> _drafts = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  String? getDraft(String chatId) {
    return _drafts[chatId];
  }

  @override
  Future<void> saveDraft(String chatId, String draft) async {
    _drafts[chatId] = draft;
  }

  @override
  Future<void> deleteDraft(String chatId) async {
    _drafts.remove(chatId);
  }
}

class MockConnectionNotifier extends ConnectionCheckerNotifier {
  @override
  Future<bool> build() async => true;
  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('ChatInput has maxLength set to AppConstants.maxInputLength', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          autoConnectionStatusProvider.overrideWith(MockConnectionNotifier.new),
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
    // We can't easily execute the buildCounter to check return value without context,
    // but we can check it's not null.
    expect(textField.buildCounter, isNotNull);

    // To be sure, we can call it if we want, but checking isNotNull is likely enough
    // to verify the property was set.
    final counter = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 0,
      isFocused: false,
      maxLength: 100
    );
    expect(counter, isNull);
  });

  testWidgets('ChatInput displays dynamic character counter correctly', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          autoConnectionStatusProvider.overrideWith(MockConnectionNotifier.new),
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
    final TextField textField = tester.widget(textFieldFinder);

    // Ensure buildCounter is not null
    expect(textField.buildCounter, isNotNull);
    final buildCounter = textField.buildCounter!;

    // Get the context from the TextField
    final context = tester.element(textFieldFinder);

    // Case 1: Length < 80% -> Hidden (null)
    expect(
      buildCounter(
        context,
        currentLength: 0,
        isFocused: true,
        maxLength: 100
      ),
      isNull
    );
    expect(
      buildCounter(
        context,
        currentLength: 79,
        isFocused: true,
        maxLength: 100
      ),
      isNull
    );

    // Case 2: 80% <= Length < 90% -> Grey
    final widget80 = buildCounter(
      context,
      currentLength: 80,
      isFocused: true,
      maxLength: 100
    );
    expect(widget80, isA<Semantics>());
    final semantics80 = widget80 as Semantics;
    expect(semantics80.properties.liveRegion, isTrue);
    expect(semantics80.child, isA<Text>());
    final text80 = semantics80.child as Text;
    expect(text80.data, '80/100');

    // Case 3: 90% <= Length < 100% -> Orange
    final widget90 = buildCounter(
      context,
      currentLength: 90,
      isFocused: true,
      maxLength: 100
    );
    expect(widget90, isA<Semantics>());
    final text90 = (widget90 as Semantics).child as Text;
    expect(text90.style?.color, Colors.orange);

    // Case 4: Length >= 100% -> Red
    final widget100 = buildCounter(
      context,
      currentLength: 100,
      isFocused: true,
      maxLength: 100
    );
    expect(widget100, isA<Semantics>());
    final text100 = (widget100 as Semantics).child as Text;
    expect(text100.style?.color, Colors.red);
  });
}
