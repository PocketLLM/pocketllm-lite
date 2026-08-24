import 'package:http/http.dart' as http;

import 'network_policy_service.dart';

class NetworkPolicyError implements Exception {
  final String message;
  const NetworkPolicyError(this.message);

  @override
  String toString() => message;
}

class NetworkGateway {
  final http.Client _client;
  final NetworkPolicyService _policy;

  NetworkGateway({http.Client? client, NetworkPolicyService? policy})
      : _client = client ?? http.Client(),
        _policy = policy ?? NetworkPolicyService();

  Future<http.Response> get(
    Uri uri, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
    Map<String, String>? headers,
  }) {
    _requireAllowed(uri, purpose, trigger, infoSent);
    return _client.get(uri, headers: headers);
  }

  Future<http.Response> post(
    Uri uri, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
    Map<String, String>? headers,
    Object? body,
  }) {
    _requireAllowed(uri, purpose, trigger, infoSent);
    return _client.post(uri, headers: headers, body: body);
  }

  Future<http.StreamedResponse> send(
    http.BaseRequest request, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) {
    _requireAllowed(request.url, purpose, trigger, infoSent);
    return _client.send(request);
  }

  Future<http.Response> delete(
    Uri uri, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
    Map<String, String>? headers,
    Object? body,
  }) {
    _requireAllowed(uri, purpose, trigger, infoSent);
    return _client.delete(uri, headers: headers, body: body);
  }

  void _requireAllowed(
    Uri uri,
    ConnectionPurpose purpose,
    String trigger,
    String infoSent,
  ) {
    final result = _policy.evaluateConnection(
      uri: uri,
      purpose: purpose,
      trigger: trigger,
      infoSent: infoSent,
    );
    if (!result.allowed) {
      throw NetworkPolicyError(result.reason ?? 'Network request blocked.');
    }
  }

  void close() => _client.close();
}
