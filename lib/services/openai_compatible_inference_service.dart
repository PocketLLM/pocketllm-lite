import 'dart:convert';

import 'package:http/http.dart' as http;

import 'inference_service.dart';
import 'network_gateway.dart';
import 'network_policy_service.dart';
import 'remote_provider_registry.dart';

class RemoteProviderError extends InferenceException {
  const RemoteProviderError(super.message, [super.cause]);
}

class OpenAiCompatibleInferenceService implements InferenceService {
  final RemoteProviderConfig config;
  final NetworkGateway _network;
  InferenceMetrics _lastMetrics = const InferenceMetrics();

  OpenAiCompatibleInferenceService(
    this.config, {
    NetworkGateway? network,
  }) : _network = network ?? NetworkGateway() {
    final uri = Uri.tryParse(config.baseUrl);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const RemoteProviderError(
        'Remote provider Base URL must be an HTTP or HTTPS URL.',
      );
    }
    for (final name in config.customHeaders.keys) {
      final normalized = name.toLowerCase();
      if ({'host', 'content-length', 'authorization'}.contains(normalized)) {
        throw RemoteProviderError('Custom header "$name" is not allowed.');
      }
    }
  }

  Uri _endpoint(String path) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final versioned = base.endsWith('/v1') ? base : '$base/v1';
    return Uri.parse('$versioned/$path');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (config.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey}',
        ...config.customHeaders,
      };

  String _modelFromSelection(String selection) {
    return RemoteProviderConfig.decodeSelection(selection)?.modelId ??
        config.modelId;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await _network
          .get(
            _endpoint('models'),
            purpose: ConnectionPurpose.remoteInference,
            trigger: 'remote_provider_connection_check',
            infoSent: 'Authorization metadata; no prompt content',
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<LLMModel>> listModels() async {
    final response = await _network
        .get(
          _endpoint('models'),
          purpose: ConnectionPurpose.remoteInference,
          trigger: 'remote_provider_model_list',
          infoSent: 'Authorization metadata; no prompt content',
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw RemoteProviderError(
        'Remote provider returned HTTP ${response.statusCode} for /v1/models.',
      );
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) {
      throw const RemoteProviderError('Remote model list is malformed.');
    }
    return data.whereType<Map>().map((item) {
      final id = item['id'];
      if (id is! String || id.isEmpty) {
        throw const RemoteProviderError('Remote model entry has no ID.');
      }
      return LLMModel(
        id: RemoteProviderConfig.encodeSelection(config.id, id),
        name: '${config.name} · $id',
        backend: InferenceBackend.remote,
        isDownloaded: false,
        supportsVision: config.supportsVision,
        supportsToolCalling: config.supportsTools,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress}) async {
    onProgress?.call(
      const InferenceProgress(progress: 1, status: 'Remote model selected'),
    );
  }

  @override
  Future<void> unloadModel(String modelId) async {}

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    final stopwatch = Stopwatch()..start();
    var promptTokens = 0;
    var completionTokens = 0;
    var completionCharacters = 0;
    final body = {
      'model': _modelFromSelection(request.modelId),
      'messages': [
        if (request.systemPrompt?.isNotEmpty ?? false)
          {'role': 'system', 'content': request.systemPrompt},
        ...request.messages.map((message) => _messageJson(message)),
      ],
      'temperature': request.temperature,
      'top_p': request.topP,
      'max_tokens': request.maxTokens,
      'stream': config.streaming,
      if (config.streaming) 'stream_options': {'include_usage': true},
    };
    if (!config.streaming) {
      final response = await _network
          .post(
            _endpoint('chat/completions'),
            purpose: ConnectionPurpose.remoteInference,
            trigger: 'remote_chat_completion',
            infoSent:
                'Model ID, conversation messages, images, and sampling options',
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        throw RemoteProviderError(
          'Remote completion returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      String? content;
      if (choices?.firstOrNull is Map) {
        final message = (choices!.first as Map)['message'];
        if (message is Map) content = message['content'] as String?;
      }
      if (content == null) {
        throw const RemoteProviderError('Remote completion had no text.');
      }
      final usage = decoded['usage'] as Map?;
      promptTokens = (usage?['prompt_tokens'] as num?)?.toInt() ?? 0;
      completionTokens = (usage?['completion_tokens'] as num?)?.toInt() ?? 0;
      completionCharacters = content.length;
      yield ChatToken(text: content);
    } else {
      final requestMessage = http.Request(
        'POST',
        _endpoint('chat/completions'),
      )
        ..headers.addAll(_headers)
        ..body = jsonEncode(body);
      final response = await _network
          .send(
            requestMessage,
            purpose: ConnectionPurpose.remoteInference,
            trigger: 'remote_chat_completion_stream',
            infoSent:
                'Model ID, conversation messages, images, and sampling options',
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw RemoteProviderError(
          'Remote completion returned HTTP ${response.statusCode}.',
        );
      }
      await for (final line in response.stream
          .timeout(const Duration(minutes: 3))
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        final decoded = jsonDecode(payload);
        if (decoded is! Map) continue;
        final usage = decoded['usage'];
        if (usage is Map) {
          promptTokens =
              (usage['prompt_tokens'] as num?)?.toInt() ?? promptTokens;
          completionTokens =
              (usage['completion_tokens'] as num?)?.toInt() ?? completionTokens;
        }
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          continue;
        }
        final delta = (choices.first as Map)['delta'];
        final content = delta is Map ? delta['content'] as String? : null;
        if (content != null && content.isNotEmpty) {
          completionCharacters += content.length;
          yield ChatToken(text: content);
        }
      }
    }
    stopwatch.stop();
    final estimated = completionTokens == 0;
    if (estimated) completionTokens = (completionCharacters / 4).ceil();
    final seconds = stopwatch.elapsedMilliseconds / 1000;
    _lastMetrics = InferenceMetrics(
      tokensPerSecond: seconds > 0 ? completionTokens / seconds : 0,
      millisecondsPerToken: completionTokens > 0
          ? stopwatch.elapsedMilliseconds / completionTokens
          : 0,
      totalTime: stopwatch.elapsed,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      tokenCountsEstimated: estimated,
    );
  }

  Map<String, dynamic> _messageJson(ChatRequestMessage message) {
    if (message.images == null || message.images!.isEmpty) {
      return {'role': message.role, 'content': message.content};
    }
    if (!config.supportsVision) {
      throw const RemoteProviderError(
        'This remote provider is not configured for vision input.',
      );
    }
    return {
      'role': message.role,
      'content': [
        {'type': 'text', 'text': message.content},
        for (final image in message.images!)
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$image'},
          },
      ],
    };
  }

  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) async {
    final response = await _network
        .post(
          _endpoint('embeddings'),
          purpose: ConnectionPurpose.remoteInference,
          trigger: 'remote_embedding',
          infoSent: 'Model ID and text to embed',
          headers: _headers,
          body: jsonEncode({
            'model': _modelFromSelection(modelId),
            'input': text,
          }),
        )
        .timeout(const Duration(minutes: 2));
    if (response.statusCode != 200) {
      throw RemoteProviderError(
        'Remote embeddings returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    final first = data is List ? data.firstOrNull : null;
    final embedding = first is Map ? first['embedding'] : null;
    if (embedding is! List) {
      throw const RemoteProviderError(
          'Remote embedding response is malformed.');
    }
    return embedding.map((value) => (value as num).toDouble()).toList();
  }

  @override
  Future<InferenceMetrics> getMetrics() async => _lastMetrics;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
