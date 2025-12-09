import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ollama_model.dart';

class OllamaService {
  Future<bool> checkConnection(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tags'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<OllamaModel>> listModels(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List models = data['models'];
        return models.map((e) => OllamaModel.fromJson(e)).toList();
      }
      throw Exception('Failed to load models');
    } catch (e) {
      rethrow;
    }
  }

  Stream<String> generateResponse({
    required String baseUrl,
    required String model,
    required String prompt,
    List<String>? images,
  }) async* {
    final uri = Uri.parse('$baseUrl/api/generate');

    final request = http.Request('POST', uri);
    request.body = jsonEncode({
      'model': model,
      'prompt': prompt,
      'images': images,
      'stream': true,
    });

    try {
      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Failed to generate response: ${streamedResponse.statusCode}',
        );
      }

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.isEmpty) continue;
          try {
            final data = jsonDecode(line);
            if (data['done'] == true) break;
            if (data.containsKey('response')) {
              yield data['response'];
            }
          } catch (e) {
            // Ignore parse errors for partial chunks
          }
        }
      }
      client.close();
    } catch (e) {
      throw Exception('Error generating response: $e');
    }
  }

  Future<void> deleteModel(String baseUrl, String modelName) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/delete'),
      body: jsonEncode({'name': modelName}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete model');
    }
  }

  Future<void> pullModel(String baseUrl, String modelName) async {
    // This is a long-running operation, often better handled by the user in Termux
    // But we can trigger it. For now, we'll just fire and forget or handle stream if needed.
    // The requirement says "app fetches/pulls via Ollama commands indirectly (user does it in Termux, app queries endpoint)".
    // But "Models List" requirements mention "Button pull/delete via API".
    // Pull API is streaming.

    final request = http.Request('POST', Uri.parse('$baseUrl/api/pull'));
    request.body = jsonEncode({'name': modelName});

    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to pull model');
    }
    // We are not consuming the stream here for simplicity, assuming the user just wants to trigger it.
    // In a full implementation, we would show progress.
  }
}
