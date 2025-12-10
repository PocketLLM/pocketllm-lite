import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../features/chat/domain/models/ollama_model.dart';

class OllamaService {
  String _baseUrl;

  OllamaService({String? baseUrl})
    : _baseUrl = baseUrl ?? AppConstants.defaultOllamaBaseUrl;

  void updateBaseUrl(String url) {
    _baseUrl = url;
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<OllamaModel>> listModels() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map((e) => OllamaModel.fromJson(e))
            .toList();
        return models;
      } else {
        throw Exception('Failed to load models: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(
        'Failed to connect to Ollama. Ensure it is running in Termux.',
      );
    }
  }

  Stream<String> generateChatStream(
    String model,
    List<Map<String, dynamic>> messages, {
    Map<String, dynamic>? options,
    String? system,
  }) async* {
    final url = Uri.parse('$_baseUrl/api/chat');

    final request = http.Request('POST', url);
    final Map<String, dynamic> body = {
      "model": model,
      "messages": messages,
      "stream": true,
    };

    if (options != null) body["options"] = options;
    if (system != null && system.isNotEmpty) {
      // Ollama supports system in messages list or top level depending on version/model.
      // Usually standard is adding a "system" role message primarily.
      // However, some endpoints support prompt/systemOverride.
      // The most compatible way is to prepend to messages list, but caller can do that.
      // If we want to explicitely set system prompt:
      // Note: Ollama chat api doesn't always strictly separate system param if messages has it.
      // We will trust the caller to put it in messages OR we can add a system message here.
      // But let's assume if 'system' arg is passed, we check if messages already has it.
    }

    request.body = jsonEncode(body);

    try {
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        await for (final chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          // Ollama typically returns JSON objects, one per line (ndjson style)
          // But a chunk might contain multiple lines or partial lines.
          // For simplicity in this demo, we assume relatively clean chunks but should split.
          final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
          for (final line in lines) {
            try {
              final json = jsonDecode(line);
              final done = json['done'] as bool? ?? false;
              if (!done) {
                final content = json['message']?['content'] as String?;
                if (content != null) {
                  yield content;
                }
              }
            } catch (e) {
              // In case of parsing error, ignore or log
              // print('Parse error: $e');
            }
          }
        }
      } else {
        throw Exception(
          'Error generating response: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> pullModel(String modelName) async {
    final url = Uri.parse('$_baseUrl/api/pull');
    // Simple pull trigger, might want to stream progress differently
    await http.post(url, body: jsonEncode({"name": modelName}));
  }

  Future<void> deleteModel(String modelName) async {
    final url = Uri.parse('$_baseUrl/api/delete');
    await http.delete(url, body: jsonEncode({"name": modelName}));
  }

  /// Non-streaming prompt enhancement using /api/chat
  /// Returns the enhanced prompt text or throws on error
  Future<String> enhancePrompt({
    required String model,
    required String userInput,
    required String systemPrompt,
  }) async {
    final url = Uri.parse('$_baseUrl/api/chat');

    // Truncate input to 2000 chars max
    final truncatedInput = userInput.length > 2000
        ? userInput.substring(0, 2000)
        : userInput;

    final body = {
      "model": model,
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": truncatedInput},
      ],
      "stream": false, // Non-streaming for quick response
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          // Trim any extra whitespace or accidental preambles
          return content.trim();
        }
        throw Exception('Empty response from model');
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Enhancement failed: $e');
    }
  }
}
