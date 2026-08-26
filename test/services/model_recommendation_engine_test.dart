import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/models/model_manifest.dart';
import 'package:pocketllm_lite/services/device_spec_service.dart';
import 'package:pocketllm_lite/services/model_recommendation_engine.dart';

void main() {
  const engine = ModelRecommendationEngine();

  DeviceHardwareProfile profile({
    double? totalRamGB = 8,
    double? availableRamGB = 4.5,
    String? thermalState = 'none',
  }) {
    return DeviceHardwareProfile(
      totalRamGB: totalRamGB,
      availableRamGB: availableRamGB,
      cpuArchitecture: 'arm64-v8a',
      cpuCores: 8,
      hasGpuAcceleration: null,
      availableStorageGB: 32,
      thermalState: thermalState,
    );
  }

  ModelManifest manifest({
    int fileSizeBytes = 2 * 1024 * 1024 * 1024,
    ModelSupportStatus status = ModelSupportStatus.installedUntested,
  }) {
    return ModelManifest(
      id: 'fixture',
      displayName: 'Fixture Q4',
      source: 'test',
      quantization: 'Q4_K_M',
      fileSizeBytes: fileSizeBytes,
      backendCompatibility: const ['Cactus folder runtime'],
      status: status,
      lastVerified: DateTime.utc(2026, 8, 25),
    );
  }

  test('untested model remains experimental even with ample RAM', () {
    final result = engine.evaluate(profile: profile(), manifest: manifest());

    expect(result.badge, RecommendationBadge.experimental);
    expect(result.loadTestedOnDevice, isFalse);
    expect(result.evidence.join(' '), contains('not completed a load test'));
  });

  test('a tested small model with measured headroom is recommended', () {
    final result = engine.evaluate(
      profile: profile(),
      manifest: manifest(
        fileSizeBytes: 1024 * 1024 * 1024,
        status: ModelSupportStatus.tested,
      ),
    );

    expect(result.badge, RecommendationBadge.recommended);
    expect(result.loadTestedOnDevice, isTrue);
    expect(result.evidence.join(' '), contains('previously completed'));
  });

  test('weight-file lower bound can trigger high memory risk', () {
    final result = engine.evaluate(
      profile: profile(totalRamGB: 4, availableRamGB: 1.8),
      manifest: manifest(fileSizeBytes: 3 * 1024 * 1024 * 1024),
    );

    expect(result.badge, RecommendationBadge.highMemoryRisk);
    expect(result.evidence.join(' '), contains('weight file alone'));
  });

  test('unknown memory never produces a confident recommendation', () {
    final result = engine.evaluate(
      profile: profile(totalRamGB: null, availableRamGB: null),
      manifest: manifest(status: ModelSupportStatus.tested),
    );

    expect(result.badge, RecommendationBadge.experimental);
    expect(result.evidence.join(' '), contains('could not be measured'));
  });

  test('explicit backend incompatibility is unsupported', () {
    final result = engine.evaluate(
      profile: profile(),
      manifest: manifest(status: ModelSupportStatus.backendUnsupported),
    );

    expect(result.badge, RecommendationBadge.unsupported);
  });

  test('severe thermal state prevents a positive label', () {
    final result = engine.evaluate(
      profile: profile(thermalState: 'severe'),
      manifest: manifest(
        fileSizeBytes: 512 * 1024 * 1024,
        status: ModelSupportStatus.tested,
      ),
    );

    expect(result.badge, RecommendationBadge.highMemoryRisk);
    expect(result.evidence.join(' '), contains('thermal state is severe'));
  });
}
