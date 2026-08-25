import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';

void main() {
  test('blocked policy fails before the HTTP client is invoked', () async {
    var invoked = false;
    final gateway = NetworkGateway(
      client: MockClient((_) async {
        invoked = true;
        return http.Response('unexpected', 200);
      }),
    );

    expect(
      () => gateway.get(
        Uri.parse('https://fonts.googleapis.com/css'),
        purpose: ConnectionPurpose.fontDownload,
        trigger: 'test',
        infoSent: 'font name',
      ),
      throwsA(isA<NetworkPolicyError>()),
    );
    expect(invoked, isFalse);
  });
}
