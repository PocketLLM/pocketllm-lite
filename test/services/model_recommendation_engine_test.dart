import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/device_spec_service.dart';
import 'package:pocketllm_lite/services/model_recommendation_engine.dart';

void main() {
  late ModelRecommendationEngine engine;

  setUp(() {
    engine = ModelRecommendationEngine();
  });

  test('small model is recommended on typical mobile hardware', () {
    const profile = DeviceHardwareProfile(
      totalRamGB: 8.0,
      availableRamGB: 4.5,
      cpuArchitecture: 'arm64',
      cpuCores: 8,
      hasGpuAcceleration: true,
      availableStorageGB: 32.0,
      thermalState: 'normal',
    );

    final result = engine.evaluateModel(
      profile: profile,
      parameterCountB: 1.7,
      quantization: 'Q4_K_M',
      contextLength: 8192,
    );

    expect(result.badge, equals(RecommendationBadge.recommended));
    expect(result.compatibilityScore, greaterThanOrEqualTo(0.75));
    expect(result.estimatedRamUsageGB, lessThan(4.5));
  });

  test('oversized model returns tooLarge badge', () {
    const profile = DeviceHardwareProfile(
      totalRamGB: 4.0,
      availableRamGB: 1.8,
      cpuArchitecture: 'arm64',
      cpuCores: 4,
      hasGpuAcceleration: false,
      availableStorageGB: 10.0,
      thermalState: 'normal',
    );

    final result = engine.evaluateModel(
      profile: profile,
      parameterCountB: 14.0,
      quantization: 'Q8_0',
      contextLength: 16384,
    );

    expect(result.badge, equals(RecommendationBadge.tooLarge));
    expect(result.compatibilityScore, lessThan(0.50));
  });

  test('unknown memory never produces a confident recommendation', () {
    const profile = DeviceHardwareProfile(
      totalRamGB: null,
      availableRamGB: null,
      cpuArchitecture: 'unknown',
      cpuCores: 4,
      hasGpuAcceleration: null,
      availableStorageGB: null,
      thermalState: null,
    );

    final result = engine.evaluateModel(
      profile: profile,
      parameterCountB: 1,
      quantization: 'Q4_K_M',
      contextLength: 4096,
    );

    expect(result.badge, RecommendationBadge.riskOfCrash);
    expect(result.estimatedSpeed, 'Not benchmarked on this device');
  });
}
