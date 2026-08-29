import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/features/model_browser/domain/model_store_model.dart';
import 'package:pocketllm_lite/services/model_store_service.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';

void main() {
  test('keeps the on-device catalog usable when speech discovery fails',
      () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/get-models')) {
        return http.Response(
          jsonEncode([
            {
              'slug': 'qwen3-0.6-embed',
              'name': 'Qwen 3 0.6B Embed',
              'size_mb': 394,
              'download_url': 'https://example.test/qwen.zip',
              'quantization': 8,
            },
          ]),
          200,
        );
      }
      return http.Response('unavailable', 503);
    });
    final service = ModelStoreService(
      network: NetworkGateway(client: client),
    );

    final catalog = await service.fetchCatalog();

    expect(catalog, hasLength(1));
    expect(catalog.single.runtime, ModelStoreRuntime.onDevice);
    expect(catalog.single.isEmbedding, isTrue);
    expect(catalog.single.license, contains('Apache-2.0'));
  });
}
