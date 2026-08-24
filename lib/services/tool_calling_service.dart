import 'dart:convert';
import 'storage_service.dart';
import 'network_gateway.dart';
import 'network_policy_service.dart';
import 'safe_math_expression.dart';

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<String> Function(Map<String, dynamic> args) handler;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.handler,
  });
}

class ToolCallingService {
  final Map<String, ToolDefinition> _tools = {};
  final StorageService _storage;
  final NetworkGateway _network;

  ToolCallingService(this._storage, {NetworkGateway? network})
      : _network = network ?? NetworkGateway() {
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
          try {
            final result = _evaluateBasicExpression(expr);
            return 'Calculation result for "$expr": $result';
          } catch (e) {
            return 'Error evaluating mathematical expression: $e';
          }
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
          final now = DateTime.now();
          final localTime =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          return 'Local Date: ${now.toIso8601String().split('T')[0]}, Local Time: $localTime, Platform: Native Mobile/Desktop Client, Timezone: ${now.timeZoneName}';
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

          final apiKey = _storage.getSetting('tavily_api_key') as String? ?? '';
          if (apiKey.isEmpty) {
            return 'Error: Tavily API Key is not configured in settings.';
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
              return 'Tavily Search API returned error code ${response.statusCode}: ${response.body}';
            }
          } catch (e) {
            return 'Error performing web search: $e';
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

  double _evaluateBasicExpression(String expression) {
    return SafeMathExpression().evaluate(expression);
  }

  /// System instruction block to give models capability to call registered tools
  String getToolSystemInstructions() {
    final buffer = StringBuffer();
    buffer.writeln('\n### AVAILABLE TOOLS');
    buffer.writeln(
      'You have access to the following native tools that you can trigger. If you need to use a tool to answer the user, you MUST write exactly:',
    );
    buffer.writeln(
      '<tool_call name="TOOL_NAME" args=\'{"PARAM_NAME": "VALUE"}\' />',
    );
    buffer.writeln(
      'Do NOT write anything else when calling a tool. The tool result will be returned to you in the next turn.',
    );
    buffer.writeln('\nList of tools:');

    for (final tool in _tools.values) {
      buffer.writeln('- Name: ${tool.name}');
      buffer.writeln('  Description: ${tool.description}');
      buffer.writeln('  Parameters: ${jsonEncode(tool.parameters)}');
    }
    buffer.writeln(
      'IMPORTANT CITATION RULE: When calling the "web_search" tool, you MUST cite the source URLs in your final response using clickable markdown links, e.g. [Source Name](URL) or [1](URL), so that the user can verify the information.',
    );
    buffer.writeln('### END OF TOOLS');
    return buffer.toString();
  }

  /// Parse `<tool_call name="calculator" args='{"expression": "2 + 2"}' />` pattern
  Map<String, String>? parseToolCall(String text) {
    final regExp = RegExp(
      r'<tool_call\s+name="([^"]+)"\s+args=\s*[\x27"]([^\x27"]+)[\x27"]\s*/>',
    );
    final match = regExp.firstMatch(text);
    if (match != null) {
      return {'name': match.group(1) ?? '', 'args': match.group(2) ?? ''};
    }
    return null;
  }
}
