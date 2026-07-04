import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/error_log_service.dart';

void main() {
  group('ErrorLogService', () {
    test(
      'keeps newest entries when rotating past the configured maximum',
      () async {
        final service = ErrorLogService.inMemory(maxEntries: 3);

        await service.logInfo(
          category: ErrorCategory.storage,
          message: 'first',
        );
        await service.logWarning(
          category: ErrorCategory.network,
          message: 'second',
        );
        await service.logError(
          category: ErrorCategory.inference,
          message: 'third',
        );
        await service.logError(
          category: ErrorCategory.modelLoading,
          message: 'fourth',
          suggestedFix: 'Try a smaller model.',
        );

        final entries = await service.getEntries();

        expect(entries, hasLength(3));
        expect(entries.map((entry) => entry.message), [
          'fourth',
          'third',
          'second',
        ]);
        expect(entries.first.severity, ErrorSeverity.error);
        expect(entries.first.suggestedFix, 'Try a smaller model.');
      },
    );

    test(
      'exports entries with severity, category, message, and suggested fix',
      () async {
        final service = ErrorLogService.inMemory(maxEntries: 10);

        await service.logError(
          category: ErrorCategory.connection,
          message: 'Ollama not reachable',
          details: 'GET /api/tags timed out',
          suggestedFix: 'Start Ollama and check the endpoint URL.',
        );

        final exported = await service.exportLog();

        expect(exported, contains('ERROR'));
        expect(exported, contains('connection'));
        expect(exported, contains('Ollama not reachable'));
        expect(exported, contains('Start Ollama and check the endpoint URL.'));
      },
    );
  });
}
