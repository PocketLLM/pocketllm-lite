import 'package:url_launcher/url_launcher.dart';

import 'network_gateway.dart';
import 'network_policy_service.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

class ExternalNavigationError implements Exception {
  final String message;

  const ExternalNavigationError(this.message);

  @override
  String toString() => message;
}

/// Opens user-visible HTTP(S) destinations through the same policy and audit
/// boundary used by PocketLLM Lite's HTTP clients.
class ExternalNavigationService {
  final NetworkPolicyService _policy;
  final ExternalUrlLauncher _launcher;

  ExternalNavigationService({
    NetworkPolicyService? policy,
    ExternalUrlLauncher? launcher,
  })  : _policy = policy ?? NetworkPolicyService(),
        _launcher = launcher ?? _launchExternally;

  Future<void> openHttpUrl(
    Uri uri, {
    required String trigger,
    String infoSent = 'Destination URL only',
  }) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw const ExternalNavigationError(
        'Only valid HTTP or HTTPS links can be opened.',
      );
    }

    final decision = _policy.evaluateConnection(
      uri: uri,
      purpose: ConnectionPurpose.externalNavigation,
      trigger: trigger,
      infoSent: infoSent,
    );
    if (!decision.allowed) {
      throw NetworkPolicyError(
        decision.reason ?? 'External navigation blocked by network policy.',
      );
    }

    if (!await _launcher(uri)) {
      throw const ExternalNavigationError(
        'No application is available to open this link.',
      );
    }
  }

  static Future<bool> _launchExternally(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
