import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/typed_tool_calling_service.dart';
import 'package:pocketllm_lite/services/safe_math_expression.dart';

void main() {
  group('TypedToolCallingService Tests', () {
    final service = TypedToolCallingService();

    setUp(() {
      service.registerTool(ToolDefinition(
        name: 'calculator',
        description: 'Basic math calculation',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'expression': {'type': 'string'}
          },
          'required': ['expression'],
          'additionalProperties': false,
        },
        handler: (args) async =>
            SafeMathExpression().evaluate(args['expression'] as String),
      ));
    });

    test('rejects malformed arguments before execution', () async {
      const call = TypedToolCall(
        id: 'c2',
        toolName: 'calculator',
        arguments: {'expression': 35},
      );
      final result = await service.executeToolCall(call);
      expect(result.success, isFalse);
      expect(result.error, contains('string'));
    });

    test('parses json tool call accurately', () {
      const response =
          'Here is the result: {"tool": "calculator", "arguments": {"expression": "12 * 5"}}';
      final calls = service.parseToolCalls(response);
      expect(calls.length, equals(1));
      expect(calls.first.toolName, equals('calculator'));
      expect(calls.first.arguments['expression'], equals('12 * 5'));
    });

    test('executes tool call and returns result', () async {
      const call = TypedToolCall(
          id: 'c1',
          toolName: 'calculator',
          arguments: {'expression': '10 + 25'});
      final result = await service.executeToolCall(call);
      expect(result.success, isTrue);
      expect(result.output, equals(35.0));
      expect(service.executionHistory.isNotEmpty, isTrue);
    });
  });
}
