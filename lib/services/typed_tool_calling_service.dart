import 'dart:async';
import 'dart:convert';

class TypedToolCall {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  const TypedToolCall({
    required this.id,
    required this.toolName,
    required this.arguments,
  });

  factory TypedToolCall.fromJson(Map<String, dynamic> json) {
    final name = json['tool'] ?? json['toolName'];
    if (name is! String || name.isEmpty || json['arguments'] is! Map) {
      throw const FormatException('Tool call requires tool and arguments.');
    }
    return TypedToolCall(
      id: json['id'] as String? ??
          'call_${DateTime.now().microsecondsSinceEpoch}',
      toolName: name,
      arguments: Map<String, dynamic>.from(json['arguments'] as Map),
    );
  }
}

class TypedToolResult {
  final String toolCallId;
  final String toolName;
  final bool success;
  final dynamic output;
  final String? error;
  final DateTime executedAt;
  const TypedToolResult({
    required this.toolCallId,
    required this.toolName,
    required this.success,
    this.output,
    this.error,
    required this.executedAt,
  });
}

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parametersSchema;
  final String networkScope;
  final bool requiresConfirmation;
  final Duration timeout;
  final Future<dynamic> Function(Map<String, dynamic> arguments) handler;
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
    required this.handler,
    this.networkScope = 'offline',
    this.requiresConfirmation = false,
    this.timeout = const Duration(seconds: 20),
  });
}

class TypedToolCallingService {
  final Map<String, ToolDefinition> _registeredTools = {};
  final List<TypedToolResult> _executionHistory = [];

  List<TypedToolResult> get executionHistory =>
      List.unmodifiable(_executionHistory);

  void registerTool(ToolDefinition definition) {
    _registeredTools[definition.name] = definition;
  }

  ToolDefinition? getTool(String name) => _registeredTools[name];

  List<TypedToolCall> parseToolCalls(String responseText) {
    final calls = <TypedToolCall>[];
    var start = responseText.indexOf('{');
    while (start >= 0) {
      var depth = 0;
      var inString = false;
      var escaped = false;
      var end = -1;
      for (var index = start; index < responseText.length; index++) {
        final character = responseText[index];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (character == r'\') {
          escaped = true;
          continue;
        }
        if (character == '"') inString = !inString;
        if (inString) continue;
        if (character == '{') depth++;
        if (character == '}') depth--;
        if (depth == 0) {
          end = index;
          break;
        }
      }
      if (end < 0) break;
      try {
        final decoded = jsonDecode(responseText.substring(start, end + 1));
        if (decoded is Map<String, dynamic> && decoded.containsKey('tool')) {
          calls.add(TypedToolCall.fromJson(decoded));
        }
      } on FormatException {
        // Non-tool JSON fragments are ignored.
      }
      start = responseText.indexOf('{', end + 1);
    }
    return calls;
  }

  Future<TypedToolResult> executeToolCall(TypedToolCall call) async {
    final definition = _registeredTools[call.toolName];
    if (definition == null) {
      return _record(call,
          success: false, error: 'Unknown tool: ${call.toolName}');
    }
    final validation = _validate(definition.parametersSchema, call.arguments);
    if (validation != null) {
      return _record(call, success: false, error: validation);
    }
    try {
      final output = await definition.handler(call.arguments).timeout(
            definition.timeout,
          );
      return _record(call, success: true, output: output);
    } on TimeoutException {
      return _record(call, success: false, error: 'Tool execution timed out.');
    } catch (error) {
      return _record(call, success: false, error: error.toString());
    }
  }

  String? _validate(
    Map<String, dynamic> schema,
    Map<String, dynamic> arguments,
  ) {
    final properties = Map<String, dynamic>.from(
      schema['properties'] as Map? ?? const {},
    );
    final required = List<String>.from(schema['required'] as List? ?? const []);
    for (final field in required) {
      if (!arguments.containsKey(field)) {
        return 'Missing required field: $field';
      }
    }
    for (final entry in arguments.entries) {
      final property = properties[entry.key];
      if (property == null && schema['additionalProperties'] == false) {
        return 'Unsupported field: ${entry.key}';
      }
      final type = property is Map ? property['type'] : null;
      if (type == 'string' && entry.value is! String) {
        return 'Field ${entry.key} must be a string';
      }
      if (type == 'number' && entry.value is! num) {
        return 'Field ${entry.key} must be a number';
      }
    }
    return null;
  }

  TypedToolResult _record(
    TypedToolCall call, {
    required bool success,
    dynamic output,
    String? error,
  }) {
    final result = TypedToolResult(
      toolCallId: call.id,
      toolName: call.toolName,
      success: success,
      output: output,
      error: error,
      executedAt: DateTime.now(),
    );
    _executionHistory.add(result);
    return result;
  }
}
