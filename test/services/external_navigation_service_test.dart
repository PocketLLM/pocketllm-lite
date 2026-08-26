import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/external_navigation_service.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class _NavigationStorage extends StorageService {
  final Map<String, dynamic> values;

  _NavigationStorage(this.values);

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    values[key] = value;
  }
}

void main() {
  late NetworkPolicyService policy;
  late List<Uri> launched;

  setUp(() {
    policy = NetworkPolicyService();
    policy.init(_NavigationStorage({}));
    launched = [];
  });

  test('opens and audits an allowed HTTP destination', () async {
    final service = ExternalNavigationService(
      policy: policy,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await service.openHttpUrl(
      Uri.parse('https://docs.ollama.com/quickstart'),
      trigger: 'documentation_link',
    );

    expect(launched, [Uri.parse('https://docs.ollama.com/quickstart')]);
    expect(policy.auditLog.first.allowed, isTrue);
    expect(policy.auditLog.first.purpose, 'externalNavigation');
    expect(policy.auditLog.first.trigger, 'documentation_link');
  });

  test('strict offline blocks launch and records the decision', () async {
    policy.init(
      _NavigationStorage({AppConstants.strictOfflineModeKey: true}),
    );
    final service = ExternalNavigationService(
      policy: policy,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await expectLater(
      service.openHttpUrl(
        Uri.parse('https://github.com/PocketLLM/pocketllm-lite'),
        trigger: 'release_link',
      ),
      throwsA(isA<NetworkPolicyError>()),
    );

    expect(launched, isEmpty);
    expect(policy.auditLog.first.allowed, isFalse);
    expect(policy.auditLog.first.blockReason, contains('Strict Offline'));
  });

  test('rejects non-HTTP schemes without invoking a launcher', () async {
    final service = ExternalNavigationService(
      policy: policy,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await expectLater(
      service.openHttpUrl(
        Uri.parse('mailto:security@example.com'),
        trigger: 'invalid_link',
      ),
      throwsA(isA<ExternalNavigationError>()),
    );

    expect(launched, isEmpty);
    expect(policy.auditLog, isEmpty);
  });
}
