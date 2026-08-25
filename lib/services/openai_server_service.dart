import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'generation_pipeline.dart';
import 'inference_service.dart';

class OpenAiServerConfig {
  final bool enabled;
  final int port;
  final String? apiKey;
  final bool localhostOnly;
  final int maxConcurrentRequests;

  const OpenAiServerConfig({
    this.enabled = false,
    this.port = 8080,
    this.apiKey,
    this.localhostOnly = true,
    this.maxConcurrentRequests = 2,
  });
}

class OpenAiServerLog {
  final DateTime timestamp;
  final String clientIp;
  final String path;
  final int statusCode;
  const OpenAiServerLog(
      this.timestamp, this.clientIp, this.path, this.statusCode);
}

class OpenAiServerService {
  static const _keyStorageName = 'openai_server_api_key_v1';
  final GenerationPipeline _pipeline;
  final Future<List<LLMModel>> Function() _listModels;
  final Future<List<double>> Function(String text, String modelId) _embed;
  final FlutterSecureStorage _secureStorage;
  HttpServer? _server;
  OpenAiServerConfig _config = const OpenAiServerConfig();
  String? _activeApiKey;
  final List<OpenAiServerLog> _logs = [];
  int _activeRequests = 0;
  final Map<String, List<DateTime>> _requestTimes = {};

  OpenAiServerService({
    required GenerationPipeline pipeline,
    required Future<List<LLMModel>> Function() listModels,
    required Future<List<double>> Function(String text, String modelId) embed,
    FlutterSecureStorage? secureStorage,
  })  : _pipeline = pipeline,
        _listModels = listModels,
        _embed = embed,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get isRunning => _server != null;
  OpenAiServerConfig get config => _config;
  String? get activeApiKey => _activeApiKey;
  List<OpenAiServerLog> get logs => List.unmodifiable(_logs);
  int? get boundPort => _server?.port;

  Future<bool> startServer(OpenAiServerConfig config) async {
    await stopServer();
    if (config.port < 0 || config.port > 65535) {
      throw ArgumentError.value(config.port, 'port', 'must be 0 to 65535');
    }
    if (config.maxConcurrentRequests < 1) {
      throw ArgumentError.value(
        config.maxConcurrentRequests,
        'maxConcurrentRequests',
        'must be at least 1',
      );
    }
    _config = config;
    if (!config.enabled) return false;
    if (config.apiKey?.trim().isNotEmpty == true) {
      _activeApiKey = config.apiKey!.trim();
    } else {
      _activeApiKey = await _secureStorage.read(key: _keyStorageName);
      if (_activeApiKey == null || _activeApiKey!.isEmpty) {
        _activeApiKey = _generateApiKey();
        await _secureStorage.write(key: _keyStorageName, value: _activeApiKey);
      }
    }
    final host = config.localhostOnly
        ? InternetAddress.loopbackIPv4
        : InternetAddress.anyIPv4;
    _server = await HttpServer.bind(host, config.port);
    _server!.listen(_handleRequest);
    return true;
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    var status = HttpStatus.internalServerError;
    var acquiredSlot = false;
    try {
      request.response.headers.contentType = ContentType.json;
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer $_activeApiKey') {
        status = HttpStatus.unauthorized;
        await _json(request.response, status, {
          'error': {'message': 'Unauthorized'}
        });
        return;
      }
      final clientIp =
          request.connectionInfo?.remoteAddress.address ?? 'unknown';
      if (!_withinRateLimit(clientIp)) {
        status = HttpStatus.tooManyRequests;
        await _json(request.response, status, {
          'error': {'message': 'Rate limit exceeded. Try again shortly.'}
        });
        return;
      }
      final needsGenerationSlot = request.method == 'POST' &&
          (request.uri.path == '/v1/chat/completions' ||
              request.uri.path == '/v1/embeddings');
      if (needsGenerationSlot &&
          _activeRequests >= _config.maxConcurrentRequests) {
        status = HttpStatus.tooManyRequests;
        await _json(request.response, status, {
          'error': {
            'message': 'Local runtime is busy. Retry after the active request.'
          }
        });
        return;
      }
      if (needsGenerationSlot) {
        _activeRequests++;
        acquiredSlot = true;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/models') {
        final models = await _listModels();
        status = HttpStatus.ok;
        await _json(request.response, status, {
          'object': 'list',
          'data': models
              .map((model) => {
                    'id': model.id,
                    'object': 'model',
                    'owned_by': model.backend.name,
                  })
              .toList(growable: false),
        });
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/chat/completions') {
        status = await _chat(request);
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/embeddings') {
        status = await _embeddings(request);
      } else {
        status = HttpStatus.notFound;
        await _json(request.response, status, {
          'error': {'message': 'Endpoint not found'}
        });
      }
    } catch (error) {
      status = HttpStatus.badRequest;
      try {
        await _json(request.response, status, {
          'error': {'message': error.toString()}
        });
      } on StateError {
        // Streaming responses may already be closed by the client.
      }
    } finally {
      if (acquiredSlot) _activeRequests--;
      _log(request, status);
    }
  }

  Future<int> _chat(HttpRequest request) async {
    final body = await _body(request);
    final model = body['model'] as String?;
    final rawMessages = body['messages'] as List?;
    if (model == null || rawMessages == null || rawMessages.isEmpty) {
      throw const FormatException('model and messages are required');
    }
    final messages = rawMessages.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final role = map['role'];
      final content = map['content'];
      if (role is! String ||
          !{'system', 'user', 'assistant', 'tool'}.contains(role) ||
          content is! String) {
        throw const FormatException(
          'Each message requires a valid role and string content.',
        );
      }
      return ChatRequestMessage(
        role: role,
        content: content,
      );
    }).toList(growable: false);
    final generation = ChatRequest(
      modelId: model,
      messages: messages,
      temperature: (body['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (body['top_p'] as num?)?.toDouble() ?? 0.9,
      maxTokens: (body['max_tokens'] as num?)?.toInt() ?? 512,
    );
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = 'chatcmpl-${DateTime.now().microsecondsSinceEpoch}';
    if (body['stream'] == true) {
      final cancellation = GenerationCancellationToken();
      unawaited(
        request.response.done.catchError((_) {
          cancellation.cancel();
        }),
      );
      request.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      request.response.headers.set('Cache-Control', 'no-cache');
      await for (final token in _pipeline.stream(
        generation,
        options: GenerationOptions(cancellationToken: cancellation),
      )) {
        request.response.write('data: ${jsonEncode({
              'id': id,
              'object': 'chat.completion.chunk',
              'created': created,
              'model': model,
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': token.text},
                  'finish_reason': null
                }
              ],
            })}\n\n');
        await request.response.flush();
      }
      request.response.write('data: ${jsonEncode({
            'id': id,
            'object': 'chat.completion.chunk',
            'created': created,
            'model': model,
            'choices': [
              {'index': 0, 'delta': {}, 'finish_reason': 'stop'}
            ],
          })}\n\n');
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
      return HttpStatus.ok;
    }
    final result = await _pipeline.complete(generation);
    await _json(request.response, HttpStatus.ok, {
      'id': id,
      'object': 'chat.completion',
      'created': created,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': result.text},
          'finish_reason': 'stop',
        }
      ],
      'usage': {
        'prompt_tokens': result.metrics.promptTokens,
        'completion_tokens': result.metrics.completionTokens,
        'total_tokens':
            result.metrics.promptTokens + result.metrics.completionTokens,
      },
    });
    return HttpStatus.ok;
  }

  Future<int> _embeddings(HttpRequest request) async {
    final body = await _body(request);
    final model = body['model'] as String?;
    final input = body['input'];
    if (model == null || (input is! String && input is! List)) {
      throw const FormatException(
          'model and string or list input are required');
    }
    final texts = input is String ? [input] : input.cast<String>();
    final data = <Map<String, dynamic>>[];
    for (var index = 0; index < texts.length; index++) {
      data.add({
        'object': 'embedding',
        'index': index,
        'embedding': await _embed(texts[index], model),
      });
    }
    await _json(request.response, HttpStatus.ok, {
      'object': 'list',
      'model': model,
      'data': data,
    });
    return HttpStatus.ok;
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.length > 4 * 1024 * 1024) {
      throw const FormatException('Request too large');
    }
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  }

  Future<void> _json(HttpResponse response, int status, Object body) async {
    response.statusCode = status;
    response.write(jsonEncode(body));
    await response.close();
  }

  void _log(HttpRequest request, int status) {
    _logs.insert(
      0,
      OpenAiServerLog(
        DateTime.now(),
        request.connectionInfo?.remoteAddress.address ?? 'unknown',
        request.uri.path,
        status,
      ),
    );
    if (_logs.length > 100) _logs.removeLast();
  }

  String _generateApiKey() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return 'pk-pllm-${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  bool _withinRateLimit(String clientIp) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));
    final times = _requestTimes.putIfAbsent(clientIp, () => []);
    times.removeWhere((time) => time.isBefore(cutoff));
    if (times.length >= 60) return false;
    times.add(now);
    return true;
  }
}
