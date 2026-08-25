import 'dart:convert';

import '../features/model_browser/domain/model_store_model.dart';
import 'network_gateway.dart';
import 'network_policy_service.dart';

class ModelStoreService {
  ModelStoreService({NetworkGateway? network})
      : _network = network ?? NetworkGateway();

  final NetworkGateway _network;

  static const _catalogRoot = 'https://vlqqczxwyaodtcdmdmlw.supabase.co';
  static const _catalogKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZscXFjenh3eWFvZHRjZG1kbWx3Iiw'
      'icm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MTg2MzIsImV4cCI6MjA2NzA5NDYzMn0.'
      'nBzqGuK9j6RZ6mOPWU2boAC_5H9XDs-fPpo5P3WZYbI';

  Map<String, String> get _headers => const {
        'apikey': _catalogKey,
        'Authorization': 'Bearer $_catalogKey',
      };

  Future<List<ModelStoreModel>> fetchCatalog() async {
    final responses = await Future.wait([
      _network.get(
        Uri.parse(
          '$_catalogRoot/functions/v1/get-models?sdk_name=flutter&sdk_version=1.3.0',
        ),
        purpose: ConnectionPurpose.modelSearch,
        trigger: 'cactus_model_store_catalog',
        infoSent: 'SDK name and pinned runtime version; no user content',
        headers: _headers,
      ),
      _network.get(
        Uri.parse('$_catalogRoot/rest/v1/whisper?select=*'),
        purpose: ConnectionPurpose.modelSearch,
        trigger: 'cactus_speech_model_catalog',
        infoSent: 'Catalog request metadata; no user content',
        headers: {..._headers, 'Accept-Profile': 'cactus'},
      ),
    ]);
    if (responses[0].statusCode != 200) {
      throw StateError(
        'On-device model catalog returned HTTP ${responses[0].statusCode}. Retry when network model browsing is enabled.',
      );
    }
    if (responses[1].statusCode != 200) {
      throw StateError(
        'Speech model catalog returned HTTP ${responses[1].statusCode}.',
      );
    }
    final models = (jsonDecode(responses[0].body) as List)
        .map((raw) => _model(Map<String, dynamic>.from(raw as Map)))
        .toList();
    final speech = (jsonDecode(responses[1].body) as List)
        .map((raw) => _speechModel(Map<String, dynamic>.from(raw as Map)))
        .where((model) => !model.id.contains('-pro'))
        .toList();
    return [...models, ...speech]..sort((left, right) {
        if (left.runtime != right.runtime) {
          return left.runtime.index.compareTo(right.runtime.index);
        }
        return left.sizeMb.compareTo(right.sizeMb);
      });
  }

  ModelStoreModel _model(Map<String, dynamic> json) {
    final id = json['slug'] as String;
    final capabilities = <String>{'Text'};
    if (json['supports_tool_calling'] == true) capabilities.add('Tools');
    if (json['supports_vision'] == true) capabilities.add('Vision');
    if (id == 'qwen3-0.6-embed' || id == 'nomic2-embed-300m') {
      capabilities
        ..remove('Text')
        ..add('Embeddings');
    }
    final url = json['download_url'] as String;
    return ModelStoreModel(
      id: id,
      name: json['name'] as String? ?? id,
      runtime: ModelStoreRuntime.onDevice,
      sizeMb: (json['size_mb'] as num).toInt(),
      downloadUrl: url,
      archiveFilename: Uri.parse(url).pathSegments.last,
      quantizationBits: (json['quantization'] as num?)?.toInt() ?? 8,
      capabilities: capabilities,
      source: 'Cactus Flutter 1.3 catalog',
    );
  }

  ModelStoreModel _speechModel(Map<String, dynamic> json) {
    final id = json['slug'] as String;
    final url = json['download_url'] as String;
    return ModelStoreModel(
      id: id,
      name: id
          .split('-')
          .map((part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
      runtime: ModelStoreRuntime.speech,
      sizeMb: int.parse(json['size_mb'].toString()),
      downloadUrl: url,
      archiveFilename:
          json['file_name'] as String? ?? Uri.parse(url).pathSegments.last,
      quantizationBits: 8,
      capabilities: const {'Speech to text'},
      source: 'Cactus Whisper catalog',
    );
  }
}
