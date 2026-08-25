import 'dart:convert';
import 'network_gateway.dart';
import 'network_policy_service.dart';
import 'safe_math_expression.dart';
import 'device_spec_service.dart';
import 'app_secret_service.dart';
import 'device_tool_action_service.dart';

enum ToolRiskLevel { low, medium, high }

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<String> Function(Map<String, dynamic> args) handler;
  final bool requiresNetwork;
  final bool requiresConfirmation;
  final ToolRiskLevel riskLevel;
  final String networkScope;
  final String filesystemScope;
  final String deviceScope;
  final Duration timeout;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.handler,
    this.requiresNetwork = false,
    this.requiresConfirmation = false,
    this.riskLevel = ToolRiskLevel.low,
    this.networkScope = 'none',
    this.filesystemScope = 'none',
    this.deviceScope = 'none',
    this.timeout = const Duration(seconds: 15),
  });
}

class ParsedToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ParsedToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class ToolExecutionResult {
  final ParsedToolCall call;
  final bool success;
  final String? output;
  final String? error;

  const ToolExecutionResult({
    required this.call,
    required this.success,
    this.output,
    this.error,
  });

  String get modelContent => jsonEncode({
        'tool_call_id': call.id,
        'tool': call.name,
        'success': success,
        if (success) 'output': output else 'error': error,
      });
}

class ToolCallingService {
  final Map<String, ToolDefinition> _tools = {};
  final NetworkGateway _network;
  final DeviceSpecService _deviceSpecs;
  final AppSecretService _secrets;
  final DeviceToolActionService _deviceActions;

  ToolCallingService({
    NetworkGateway? network,
    DeviceSpecService? deviceSpecs,
    AppSecretService? secrets,
    DeviceToolActionService? deviceActions,
  })  : _network = network ?? NetworkGateway(),
        _deviceSpecs = deviceSpecs ?? DeviceSpecService(),
        _secrets = secrets ?? const AppSecretService(),
        _deviceActions = deviceActions ?? PlatformDeviceToolActionService() {
    _registerDefaultTools();
  }

  void _registerDefaultTools() {
    // 1. Calculator Tool
    registerTool(
      ToolDefinition(
        name: 'calculator',
        description:
            'Evaluate mathematical expressions. Input format: {"expression": "math expression to calculate, e.g. (12 + 8) * 5"}',
        parameters: {
          'type': 'object',
          'properties': {
            'expression': {
              'type': 'string',
              'description': 'The math expression to evaluate',
            },
          },
          'required': ['expression'],
        },
        handler: (args) async {
          final expr = args['expression'] as String? ?? '';
          final result = _evaluateBasicExpression(expr);
          return 'Calculation result for "$expr": $result';
        },
      ),
    );

    registerTool(
      ToolDefinition(
        name: 'clipboard',
        description:
            'Copy text to the system clipboard after the user confirms. Input format: {"text":"text to copy"}',
        parameters: {
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
          },
          'required': ['text'],
        },
        requiresConfirmation: true,
        riskLevel: ToolRiskLevel.medium,
        deviceScope: 'clipboard-write',
        handler: (args) async {
          final value = (args['text'] as String).trim();
          await _deviceActions.copyToClipboard(value);
          return jsonEncode({'copied': true, 'characters': value.length});
        },
      ),
    );

    registerTool(
      ToolDefinition(
        name: 'notes',
        description:
            'Create a persistent local note after the user confirms. Input format: {"title":"note title","content":"note content"}',
        parameters: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'content': {'type': 'string'},
          },
          'required': ['title', 'content'],
        },
        requiresConfirmation: true,
        riskLevel: ToolRiskLevel.medium,
        filesystemScope: 'app-private-note-storage-write',
        handler: (args) async {
          final note = await _deviceActions.createNote(
            args['title'] as String,
            args['content'] as String,
          );
          return jsonEncode(note);
        },
      ),
    );

    registerTool(
      ToolDefinition(
        name: 'reminders',
        description:
            'Schedule a local notification after confirmation. scheduled_at must be an ISO 8601 date-time with an explicit offset. Input format: {"title":"title","body":"details","scheduled_at":"2026-08-25T18:30:00+02:00"}',
        parameters: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'body': {'type': 'string'},
            'scheduled_at': {'type': 'string'},
          },
          'required': ['title', 'body', 'scheduled_at'],
        },
        requiresConfirmation: true,
        riskLevel: ToolRiskLevel.medium,
        deviceScope: 'local-notification-schedule',
        timeout: const Duration(seconds: 30),
        handler: (args) async {
          final raw = args['scheduled_at'] as String;
          final when = DateTime.tryParse(raw);
          if (when == null ||
              (!raw.endsWith('Z') &&
                  !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw))) {
            throw const FormatException(
              'scheduled_at must include Z or an explicit UTC offset.',
            );
          }
          final id = await _deviceActions.scheduleReminder(
            args['title'] as String,
            args['body'] as String,
            when,
          );
          return jsonEncode({'scheduled': true, 'notification_id': id});
        },
      ),
    );

    registerTool(
      ToolDefinition(
        name: 'draft_email',
        description:
            'Open the system email composer with a draft. It never sends automatically. Input format: {"recipient":"name@example.com","subject":"subject","body":"message"}',
        parameters: {
          'type': 'object',
          'properties': {
            'recipient': {'type': 'string'},
            'subject': {'type': 'string'},
            'body': {'type': 'string'},
          },
          'required': ['recipient', 'subject', 'body'],
        },
        requiresConfirmation: true,
        riskLevel: ToolRiskLevel.medium,
        deviceScope: 'external-email-composer',
        handler: (args) async {
          await _deviceActions.openEmailDraft(
            recipient: args['recipient'] as String,
            subject: args['subject'] as String,
            body: args['body'] as String,
          );
          return jsonEncode({'draft_opened': true, 'sent': false});
        },
      ),
    );

    registerTool(
      ToolDefinition(
        name: 'open_url',
        description:
            'Open an HTTP or HTTPS URL in the system browser after confirmation. Strict Offline is enforced. Input format: {"url":"https://example.com"}',
        parameters: {
          'type': 'object',
          'properties': {
            'url': {'type': 'string'},
          },
          'required': ['url'],
        },
        requiresNetwork: true,
        requiresConfirmation: true,
        riskLevel: ToolRiskLevel.high,
        networkScope: 'user-confirmed-http-navigation',
        deviceScope: 'external-browser',
        handler: (args) async {
          final uri = Uri.tryParse(args['url'] as String);
          if (uri == null) throw const FormatException('URL is invalid.');
          await _deviceActions.openWebUrl(uri);
          return jsonEncode({'opened': uri.toString()});
        },
      ),
    );

    // 2. System Information Tool
    registerTool(
      ToolDefinition(
        name: 'system_info',
        description:
            'Get local system details, local time, and platform parameters. Input format: {}',
        parameters: {'type': 'object', 'properties': {}},
        handler: (args) async {
          final profile = await _deviceSpecs.getHardwareProfile(refresh: true);
          final now = DateTime.now();
          final localTime =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          String measured(double? value, String unit) => value == null
              ? 'unavailable'
              : '${value.toStringAsFixed(2)} $unit';
          return jsonEncode({
            'localDate': now.toIso8601String().split('T')[0],
            'localTime': localTime,
            'timezone': now.timeZoneName,
            'cpuArchitecture': profile.cpuArchitecture,
            'cpuCores': profile.cpuCores,
            'totalRam': measured(profile.totalRamGB, 'GiB'),
            'availableRam': measured(profile.availableRamGB, 'GiB'),
            'availableStorage': measured(profile.availableStorageGB, 'GiB'),
            'gpuAcceleration': profile.hasGpuAcceleration ?? 'unavailable',
            'thermalState': profile.thermalState ?? 'unavailable',
            'batteryLevel': profile.batteryLevel ?? 'unavailable',
          });
        },
      ),
    );

    // Knowledge search is intentionally not registered until a real local corpus
    // is selected. Web search remains an explicit, policy-gated online tool.
    registerTool(
      ToolDefinition(
        name: 'web_search',
        description:
            'Search the live internet for recent facts, news, and real-time information. Input format: {"query": "search query string, e.g. OpenAI GPT-4o release date"}',
        parameters: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query to look up on the internet',
            },
          },
          'required': ['query'],
        },
        handler: (args) async {
          final query = args['query'] as String? ?? '';
          if (query.trim().isEmpty) return 'Please specify a search query.';

          final apiKey = await _secrets.getTavilyApiKey() ?? '';
          if (apiKey.isEmpty) {
            throw StateError(
              'Tavily API Key is not configured in settings.',
            );
          }

          try {
            final url = Uri.parse('https://api.tavily.com/search');
            final response = await _network.post(
              url,
              purpose: ConnectionPurpose.webSearch,
              trigger: 'tool_web_search',
              infoSent: 'Search query text',
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'api_key': apiKey,
                'query': query,
                'search_depth': 'basic',
                'max_results': 5,
                'include_answer': true,
              }),
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final resultsList = data['results'] as List? ?? [];
              final answer = data['answer'] as String? ?? '';

              if (resultsList.isEmpty) {
                return 'No results found for "$query".';
              }

              final buffer = StringBuffer();
              if (answer.isNotEmpty) {
                buffer.writeln('Summary Answer: $answer\n');
              }
              buffer.writeln('Search Results for "$query":');
              for (int i = 0; i < resultsList.length; i++) {
                final res = resultsList[i];
                final title = res['title'] ?? 'No Title';
                final link = res['url'] ?? '';
                final snippet = res['content'] ?? '';
                buffer.writeln('[Source ${i + 1}] Title: $title');
                buffer.writeln('URL: $link');
                buffer.writeln('Snippet: $snippet\n');
              }
              return buffer.toString();
            } else {
              throw StateError(
                'Tavily Search API returned HTTP ${response.statusCode}.',
              );
            }
          } catch (e) {
            throw StateError('Web search failed: $e');
          }
        },
      ),
    );
  }

  void registerTool(ToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  List<ToolDefinition> getAvailableTools() {
    return _tools.values.toList();
  }

  ToolDefinition? getTool(String name) {
    return _tools[name];
  }

  String? validateArguments(ToolDefinition tool, Map<String, dynamic> args) {
    final properties = Map<String, dynamic>.from(
      tool.parameters['properties'] as Map? ?? const {},
    );
    final required = List<String>.from(
      tool.parameters['required'] as List? ?? const [],
    );
    for (final name in required) {
      if (!args.containsKey(name)) return 'Missing required argument: $name';
    }
    for (final entry in args.entries) {
      final schema = properties[entry.key];
      if (schema == null) return 'Unsupported argument: ${entry.key}';
      final type = (schema as Map)['type'];
      if (type == 'string' && entry.value is! String) {
        return 'Argument ${entry.key} must be a string';
      }
    }
    return null;
  }

  double _evaluateBasicExpression(String expression) {
    return SafeMathExpression().evaluate(expression);
  }

  /// System instruction block to give models capability to call registered tools
  String getToolSystemInstructions({Set<String>? allowedTools}) {
    final buffer = StringBuffer();
    buffer.writeln('\n### AVAILABLE TOOLS');
    buffer.writeln(
      'You have access to native tools. To call one, return exactly one JSON object:',
    );
    buffer.writeln(
      '{"tool":"TOOL_NAME","arguments":{"PARAM_NAME":"VALUE"}}',
    );
    buffer.writeln(
      'Do NOT write anything else when calling a tool. The tool result will be returned to you in the next turn.',
    );
    buffer.writeln('\nList of tools:');

    final exposed = _tools.values.where(
      (tool) => allowedTools == null || allowedTools.contains(tool.name),
    );
    for (final tool in exposed) {
      buffer.writeln('- Name: ${tool.name}');
      buffer.writeln('  Description: ${tool.description}');
      buffer.writeln('  Parameters: ${jsonEncode(tool.parameters)}');
      buffer.writeln('  Risk: ${tool.riskLevel.name}');
      buffer.writeln('  Confirmation required: ${tool.requiresConfirmation}');
    }
    buffer.writeln(
      'IMPORTANT CITATION RULE: When calling the "web_search" tool, you MUST cite the source URLs in your final response using clickable markdown links, e.g. [Source Name](URL) or [1](URL), so that the user can verify the information.',
    );
    buffer.writeln('### END OF TOOLS');
    return buffer.toString();
  }

  Map<String, String>? parseToolCall(String text) {
    final calls = parseToolCalls(text);
    if (calls.isEmpty) return null;
    return {
      'name': calls.first.name,
      'args': jsonEncode(calls.first.arguments),
    };
  }

  List<ParsedToolCall> parseToolCalls(String text) {
    final calls = <ParsedToolCall>[];
    var start = text.indexOf('{');
    while (start >= 0) {
      final end = _findJsonObjectEnd(text, start);
      if (end < 0) break;
      try {
        final decoded = jsonDecode(text.substring(start, end + 1));
        if (decoded is Map<String, dynamic> &&
            decoded['tool'] is String &&
            decoded['arguments'] is Map) {
          calls.add(
            ParsedToolCall(
              id: decoded['id'] as String? ??
                  'call_${DateTime.now().microsecondsSinceEpoch}_${calls.length}',
              name: decoded['tool'] as String,
              arguments: Map<String, dynamic>.from(
                decoded['arguments'] as Map,
              ),
            ),
          );
        }
      } on FormatException {
        // Non-tool JSON fragments are ignored.
      }
      start = text.indexOf('{', end + 1);
    }
    if (calls.isNotEmpty) return calls;

    final legacy = RegExp(
      r'<tool_call\s+name="([^"]+)"\s+args=\s*[\x27"]([^\x27"]+)[\x27"]\s*/>',
    );
    for (final match in legacy.allMatches(text)) {
      try {
        final arguments = jsonDecode(match.group(2) ?? '');
        if (arguments is Map) {
          calls.add(
            ParsedToolCall(
              id: 'legacy_${DateTime.now().microsecondsSinceEpoch}_${calls.length}',
              name: match.group(1) ?? '',
              arguments: Map<String, dynamic>.from(arguments),
            ),
          );
        }
      } on FormatException {
        // Malformed compatibility calls are rejected by returning no call.
      }
    }
    return calls;
  }

  Future<ToolExecutionResult> execute(
    ParsedToolCall call, {
    Set<String>? allowedTools,
    Future<bool> Function(ToolDefinition tool, ParsedToolCall call)? confirm,
  }) async {
    if (allowedTools != null && !allowedTools.contains(call.name)) {
      return ToolExecutionResult(
        call: call,
        success: false,
        error: 'Tool is not enabled for this request: ${call.name}',
      );
    }
    final tool = getTool(call.name);
    if (tool == null) {
      return ToolExecutionResult(
        call: call,
        success: false,
        error: 'Unknown tool: ${call.name}',
      );
    }
    final validation = validateArguments(tool, call.arguments);
    if (validation != null) {
      return ToolExecutionResult(
        call: call,
        success: false,
        error: 'Tool validation failed: $validation',
      );
    }
    if (tool.requiresConfirmation) {
      final approved = confirm != null && await confirm(tool, call);
      if (!approved) {
        return ToolExecutionResult(
          call: call,
          success: false,
          error: 'Tool execution was not confirmed by the user.',
        );
      }
    }
    try {
      return ToolExecutionResult(
        call: call,
        success: true,
        output: await tool.handler(call.arguments).timeout(tool.timeout),
      );
    } catch (error) {
      return ToolExecutionResult(
        call: call,
        success: false,
        error: error.toString(),
      );
    }
  }

  int _findJsonObjectEnd(String text, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var index = start; index < text.length; index++) {
      final character = text[index];
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
      if (depth == 0) return index;
    }
    return -1;
  }
}
