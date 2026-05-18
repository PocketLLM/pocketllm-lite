import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/model_browser/domain/hf_model.dart';

class HuggingFaceService {
  final http.Client _client = http.Client();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _hfTokenKey = 'hf_access_token';

  Future<void> setToken(String token) async {
    await _secureStorage.write(key: _hfTokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _hfTokenKey);
  }

  Future<void> removeToken() async {
    await _secureStorage.delete(key: _hfTokenKey);
  }

  Map<String, String> _buildHeaders(String? token) {
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  Future<List<HFModel>> searchModels({
    String query = '',
    int limit = 20,
    String sort = 'downloads', // downloads, likes, lastModified
  }) async {
    final token = await getToken();

    // Build URL query parameters
    final Map<String, String> queryParams = {
      'library': 'gguf',
      'sort': sort,
      'direction': '-1',
      'limit': limit.toString(),
    };
    if (query.isNotEmpty) {
      queryParams['search'] = query;
    }

    final uri = Uri.https('huggingface.co', '/api/models', queryParams);

    final response = await _client.get(uri, headers: _buildHeaders(token));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => HFModel.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to search HuggingFace models: ${response.statusCode}',
      );
    }
  }

  Future<HFModel> getModelDetails(String modelId) async {
    final token = await getToken();
    final uri = Uri.https('huggingface.co', '/api/models/$modelId');

    final response = await _client.get(uri, headers: _buildHeaders(token));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // Also fetch README.md for description
      String? description;
      try {
        final readmeResponse = await _client.get(
          Uri.parse('https://huggingface.co/$modelId/resolve/main/README.md'),
          headers: _buildHeaders(token),
        );
        if (readmeResponse.statusCode == 200) {
          description = readmeResponse.body;
        }
      } catch (_) {
        // Ignore failure to fetch readme
      }

      final baseModel = HFModel.fromJson(json);
      return HFModel(
        id: baseModel.id,
        author: baseModel.author,
        name: baseModel.name,
        downloads: baseModel.downloads,
        likes: baseModel.likes,
        tags: baseModel.tags,
        lastModified: baseModel.lastModified,
        pipelineTag: baseModel.pipelineTag,
        isGated: baseModel.isGated,
        description: description,
      );
    } else {
      throw Exception('Failed to get model details: ${response.statusCode}');
    }
  }

  Future<List<HFModelFile>> getModelFiles(String modelId) async {
    final token = await getToken();
    final uri = Uri.https('huggingface.co', '/api/models/$modelId/tree/main');

    final response = await _client.get(uri, headers: _buildHeaders(token));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);

      // Filter only .gguf files
      final files = jsonList
          .where(
            (item) =>
                item['type'] == 'file' &&
                item['path'].toString().endsWith('.gguf'),
          )
          .map((item) => HFModelFile.fromJson(item, modelId))
          .toList();

      // Sort by size ascending
      files.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
      return files;
    } else {
      throw Exception('Failed to get model files: ${response.statusCode}');
    }
  }
}
