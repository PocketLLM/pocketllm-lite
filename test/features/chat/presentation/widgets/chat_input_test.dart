import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_input.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
import 'package:pocketllm_lite/services/file_service.dart';
import 'package:pocketllm_lite/services/ollama_service.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}
}

// Mock FileService
class MockFileService implements FileService {
  @override
  Future<List<PlatformFile>> pickTextFiles() async => [];

  @override
  Future<String> readFileContent(PlatformFile file) async => '';
}

// Mock OllamaService
class MockOllamaService extends OllamaService {
  @override
  Future<bool> checkConnection() async => true;
}

void main() {
  testWidgets('ChatInput has maxLength set to AppConstants.maxInputLength', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final mockFileService = MockFileService();
    final mockOllamaService = MockOllamaService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
          fileServiceProvider.overrideWithValue(mockFileService),
          ollamaServiceProvider.overrideWithValue(mockOllamaService),
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
}
