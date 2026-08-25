import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';

class _PolicyStorage extends StorageService {
  final Map<String, dynamic> values;
  _PolicyStorage(this.values);

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    values[key] = value;
  }
}

void main() {
  late NetworkPolicyService service;

  setUp(() {
    service = NetworkPolicyService();
    service.init(_PolicyStorage({}));
  });

  test('strict offline blocks every non-loopback operation centrally', () {
    service.init(
      _PolicyStorage({AppConstants.strictOfflineModeKey: true}),
    );
    for (final purpose in ConnectionPurpose.values) {
      final result = service.evaluateConnection(
        uri: Uri.parse('https://external.example/resource'),
        purpose: purpose,
        trigger: 'strict_offline_test',
        infoSent: 'No sensitive content',
      );
      expect(result.allowed, isFalse, reason: purpose.name);
      expect(result.reason, contains('Strict Offline'));
    }
    final local = service.evaluateConnection(
      uri: Uri.parse('http://127.0.0.1:11434/api/tags'),
      purpose: ConnectionPurpose.remoteInference,
      trigger: 'strict_offline_loopback_test',
      infoSent: 'Prompt content to user-selected loopback endpoint',
    );
    expect(local.allowed, isTrue);
  });

  test('isLoopback correctly identifies local endpoints', () {
    expect(service.isLoopback(Uri.parse('http://127.0.0.1:11434')), isTrue);
    expect(service.isLoopback(Uri.parse('http://localhost:11434')), isTrue);
    expect(service.isLoopback(Uri.parse('http://0.0.0.0:8080')), isTrue);
    expect(service.isLoopback(Uri.parse('https://api.github.com')), isFalse);
    expect(service.isLoopback(Uri.parse('https://huggingface.co')), isFalse);
  });

  test('loopback requests are allowed regardless of default policy', () {
    final result = service.evaluateConnection(
      uri: Uri.parse('http://127.0.0.1:11434'),
      purpose: ConnectionPurpose.remoteInference,
      trigger: 'chat_prompt',
      infoSent: 'Local prompt text',
    );

    expect(result.allowed, isTrue);
    expect(service.auditLog, isNotEmpty);
    expect(service.auditLog.first.domain, equals('127.0.0.1'));
  });

  test('font downloads are blocked when runtime font fetching is disabled', () {
    final result = service.evaluateConnection(
      uri: Uri.parse('https://fonts.googleapis.com/css'),
      purpose: ConnectionPurpose.fontDownload,
      trigger: 'font_request',
      infoSent: 'Inter font family request',
    );

    expect(result.allowed, isFalse);
    expect(result.reason, contains('Runtime font downloading is disabled'));
  });

  test('automatic update preference has one policy-backed source of truth',
      () async {
    expect(service.isAutoUpdateCheckEnabled, isFalse);

    await service.setAutoUpdateCheckEnabled(true);

    expect(service.isAutoUpdateCheckEnabled, isTrue);
    final automatic = service.evaluateConnection(
      uri: Uri.parse('https://api.github.com/releases/latest'),
      purpose: ConnectionPurpose.updateCheck,
      trigger: 'auto_update_check',
      infoSent: 'App version only',
    );
    expect(automatic.allowed, isTrue);
  });

  test('manual update actions do not require background update opt-in', () {
    for (final purpose in [
      ConnectionPurpose.manualUpdateCheck,
      ConnectionPurpose.updateDownload,
    ]) {
      final result = service.evaluateConnection(
        uri: Uri.parse('https://github.com/release.apk'),
        purpose: purpose,
        trigger: 'user_action',
        infoSent: 'No user content',
      );
      expect(result.allowed, isTrue, reason: purpose.name);
    }
  });
}
