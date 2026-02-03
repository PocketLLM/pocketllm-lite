import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/chat_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/prompt_enhancer_provider.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/connection_status_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/draft_message_provider.dart';

// Mocks
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
  List<Map<String, String>> getMessageTemplates() => [];
}

class MockChatNotifier extends ChatNotifier {
  @override
  ChatState build() {
    return ChatState(messages: [], isGenerating: false);
  }
}

class MockPromptEnhancerNotifier extends PromptEnhancerNotifier {
  @override
  PromptEnhancerState build() {
    return PromptEnhancerState();
  }
}

class MockUsageLimitsNotifier extends UsageLimitsNotifier {
  @override
  UsageLimitsState build() {
    return UsageLimitsState();
  }
}

class MockConnectionCheckerNotifier extends ConnectionCheckerNotifier {
  @override
  Future<bool> build() async {
    return true;
  }
  @override
  Future<void> refresh() async {
    state = const AsyncData(true);
  }
}

void main() {
  testWidgets('Send button tooltip shows keyboard shortcut', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          chatProvider.overrideWith(MockChatNotifier.new),
          promptEnhancerProvider.overrideWith(MockPromptEnhancerNotifier.new),
          usageLimitsProvider.overrideWith(MockUsageLimitsNotifier.new),
          autoConnectionStatusProvider.overrideWith(MockConnectionCheckerNotifier.new),
          draftMessageProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInput(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Send button tooltip
    final sendButtonFinder = find.byTooltip('Send (Ctrl+Enter)');
    expect(sendButtonFinder, findsOneWidget);
  });
}
