import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/services/tool_calling_service.dart';

class _Storage extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => defaultValue;
}

void main() {
  final service = ToolCallingService(_Storage());

  test('parses canonical JSON tool calls and validates strict arguments', () {
    final call = service.parseToolCall(
      '{"tool":"calculator","arguments":{"expression":"(2 + 3) * 4"}}',
    );
    expect(call?['name'], 'calculator');
    final tool = service.getTool('calculator')!;
    expect(
        service.validateArguments(tool, {'expression': '(2 + 3) * 4'}), isNull);
    expect(service.validateArguments(tool, {'expression': 20}),
        contains('string'));
    expect(
      service.validateArguments(tool, {'expression': '2', 'shell': 'rm'}),
      contains('Unsupported'),
    );
  });

  test('calculator handler uses safe precedence-aware evaluation', () async {
    final tool = service.getTool('calculator')!;
    expect(await tool.handler({'expression': '(2 + 3) * -4'}), contains('-20'));
    expect(await tool.handler({'expression': '1 / 0'}),
        contains('Division by zero'));
  });

  test('does not expose canned knowledge search', () {
    expect(service.getTool('knowledge_search'), isNull);
  });
}
