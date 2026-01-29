import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/chat_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/connection_status_provider.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  @override
  String? getDraft(String key) => null;

  @override
  Future<void> saveDraft(String key, String draft) async {}

  @override
  Future<void> deleteDraft(String key) async {}

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}
}

// Mock ConnectionCheckerNotifier
class MockConnectionCheckerNotifier extends ConnectionCheckerNotifier {
  @override
  Future<bool> build() async {
    return true; // Always connected
  }

  @override
  Future<void> refresh() async {
    // No-op
  }
}

void main() {
  testWidgets('ChatInput "Add Image" opens bottom sheet with accessible header', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          chatProvider.overrideWith(ChatNotifier.new),
          autoConnectionStatusProvider.overrideWith(MockConnectionCheckerNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInput(),
          ),
        ),
      ),
    );

    // Ensure semantics are enabled for the test
    final handle = tester.ensureSemantics();

    // Find "Add Image" button (Semantics label 'Add Image')
    final addImageBtn = find.bySemanticsLabel('Add Image');
    expect(addImageBtn, findsOneWidget);

    // Tap it
    await tester.tap(addImageBtn);
    await tester.pumpAndSettle(); // Wait for bottom sheet animation

    // Verify "Attach Image" text exists
    final titleFinder = find.text('Attach Image');
    expect(titleFinder, findsOneWidget);

    // Verify it is a header
    final node = tester.getSemantics(titleFinder);

    // Should be a header.
    expect(node.hasFlag(SemanticsFlag.isHeader), isTrue, reason: 'Title should be a semantic header');

    // Verify Camera/Gallery options exist
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    handle.dispose();
  });
}
