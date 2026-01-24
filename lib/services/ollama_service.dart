import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/utils/url_validator.dart';
import '../features/chat/domain/models/ollama_model.dart';
import '../features/chat/domain/models/ollama_model_details.dart';
import '../features/chat/domain/models/pull_progress.dart';

class OllamaService {
  String _baseUrl;
  final http.Client _client;

  OllamaService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? AppConstants.defaultOllamaBaseUrl,
      _client = client ?? http.Client() {
    // Security: Validate URL scheme to prevent non-HTTP protocols
    if (!UrlValidator.isHttpUrlString(_baseUrl)) {
      throw ArgumentError(
        'Invalid Ollama URL. Must start with http:// or https://',
      );
    }
  }

  void updateBaseUrl(String url) {
    if (!UrlValidator.isHttpUrlString(url)) {
      throw ArgumentError(
        'Invalid Ollama URL. Must start with http:// or https://',
      );
    }
    _baseUrl = url;
  }

  Future<bool> checkConnection() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(AppConstants.apiConnectionTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<OllamaModel>> listModels() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(AppConstants.apiConnectionTimeout);
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
    
    // Handle system prompt by prepending it to messages if provided
    final List<Map<String, dynamic>> finalMessages = List.from(messages);
    if (system != null && system.isNotEmpty) {
      // Check if a system message already exists at the beginning
      bool hasSystem = false;
      if (finalMessages.isNotEmpty) {
        hasSystem = finalMessages.first['role'] == 'system';
      }
      
      if (!hasSystem) {
        finalMessages.insert(0, {
          "role": "system",
          "content": system,
        });
      }
    }
    body["messages"] = finalMessages;

    request.body = jsonEncode(body);

    try {
      // We can't use _client.send(request) directly if _client is a standard IOClient 
      // because we want a streamed response. 
      // However, for testing with MockClient, we want to use the injected client.
      // Standard http.Client.send returns a StreamedResponse.
      final streamedResponse = await _client
          .send(request)
          .timeout(AppConstants.apiConnectionTimeout);

      if (streamedResponse.statusCode == 200) {
        // Use LineSplitter to correctly handle chunks that might be split
        // across JSON object boundaries, ensuring no data is lost and reducing string allocations.
        await for (final line in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.trim().isEmpty) continue;
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
      } else {
        throw Exception(
          'Error generating response: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Stream<PullProgress> pullModel(String modelName) async* {
    final url = Uri.parse('$_baseUrl/api/pull');
    final request = http.Request('POST', url);
    request.body = jsonEncode({"name": modelName});

    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(AppConstants.apiConnectionTimeout);

      if (streamedResponse.statusCode == 200) {
        // Use LineSplitter to properly handle split chunks in NDJSON stream
        await for (final line in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line);
            yield PullProgress.fromJson(json);
          } catch (e) {
            // ignore parse errors
          }
        }
      } else {
        throw Exception('Failed to pull model: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during pull: $e');
    }
  }

  Future<void> deleteModel(String modelName) async {
    final url = Uri.parse('$_baseUrl/api/delete');
    await _client
        .delete(url, body: jsonEncode({"name": modelName}))
        .timeout(AppConstants.apiConnectionTimeout);
  }

  Future<OllamaModelDetails> getModelDetails(String modelName) async {
    final url = Uri.parse('$_baseUrl/api/show');
    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"name": modelName}),
          )
          .timeout(AppConstants.apiConnectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OllamaModelDetails.fromJson(data);
      } else {
        throw Exception(
          'Failed to load model details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error fetching model details: $e');
    }
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
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConstants.apiGenerationTimeout);

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
