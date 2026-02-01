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
  String? getDraft(String key) => null;

  @override
  Future<void> saveDraft(String key, String content) async {}

  @override
  Future<void> deleteDraft(String key) async {}
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

    // Verify buildCounter is set
    expect(textField.buildCounter, isNotNull);

    // Verify it is hidden for low character counts (<= 80%)
    final hiddenCounter = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 50,
      isFocused: false,
      maxLength: 100,
    );
    expect(hiddenCounter, isNull);

    // Verify it is visible for high character counts (> 80%)
    final visibleCounter = textField.buildCounter!(
      tester.element(textFieldFinder),
      currentLength: 81,
      isFocused: false,
      maxLength: 100,
    );
    expect(visibleCounter, isNotNull);
    expect(visibleCounter, isA<Semantics>());
    expect((visibleCounter as Semantics).properties.liveRegion, isTrue);
  });
}
