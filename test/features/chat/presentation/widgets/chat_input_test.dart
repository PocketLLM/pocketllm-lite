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
  final Map<String, dynamic> _settings = {};
  final Map<String, String> _drafts = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
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

class MockConnectionCheckerNotifier extends ConnectionCheckerNotifier {
  @override
  Future<bool> build() async {
    return true;
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('ChatInput has maxLength set to AppConstants.maxInputLength',
      (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          autoConnectionStatusProvider
              .overrideWith(MockConnectionCheckerNotifier.new),
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

  testWidgets('ChatInput displays correct tooltip with shortcut',
      (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          autoConnectionStatusProvider
              .overrideWith(MockConnectionCheckerNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInput(),
          ),
        ),
      ),
    );

    // Find the IconButton that contains the send icon
    final sendIconFinder = find.byKey(const ValueKey('send_icon'));
    expect(sendIconFinder, findsOneWidget);

    final iconButtonFinder = find.ancestor(
      of: sendIconFinder,
      matching: find.byType(IconButton),
    );
    expect(iconButtonFinder, findsOneWidget);

    final IconButton iconButton = tester.widget(iconButtonFinder);

    // Default platform in tests is usually Android, so we expect 'Send (Ctrl+Enter)'
    expect(iconButton.tooltip, 'Send (Ctrl+Enter)');
  });
}
