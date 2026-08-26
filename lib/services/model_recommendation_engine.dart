import '../models/model_manifest.dart';
import 'device_spec_service.dart';

enum RecommendationBadge {
  recommended,
  likelyCompatible,
  experimental,
  highMemoryRisk,
  unsupported,
}

extension RecommendationBadgeExtension on RecommendationBadge {
  String get label => switch (this) {
        RecommendationBadge.recommended => 'Recommended',
        RecommendationBadge.likelyCompatible => 'Likely compatible',
        RecommendationBadge.experimental => 'Experimental',
        RecommendationBadge.highMemoryRisk => 'High memory risk',
        RecommendationBadge.unsupported => 'Unsupported',
      };
}

class ModelRecommendationResult {
  final RecommendationBadge badge;
  final double? fileSizeGB;
  final double? availableRamGB;
  final bool loadTestedOnDevice;
  final List<String> evidence;

  const ModelRecommendationResult({
    required this.badge,
    required this.fileSizeGB,
    required this.availableRamGB,
    required this.loadTestedOnDevice,
    required this.evidence,
  });
}

/// Produces conservative compatibility labels from facts PocketLLM actually
/// knows. A GGUF file size is a lower bound, not a RAM estimate, and no speed,
/// accelerator, or quality score is invented here.
class ModelRecommendationEngine {
  const ModelRecommendationEngine();

  ModelRecommendationResult evaluate({
    required DeviceHardwareProfile profile,
    required ModelManifest manifest,
  }) {
    final evidence = <String>[];
    final fileSizeGB = manifest.fileSizeBytes > 0
        ? manifest.fileSizeBytes / (1024 * 1024 * 1024)
        : null;
    final availableRamGB = profile.availableRamGB;
    final totalRamGB = profile.totalRamGB;
    final loadTested = manifest.status == ModelSupportStatus.tested;

    if (manifest.status == ModelSupportStatus.backendUnsupported) {
      evidence.add('The installed manifest marks this backend as unsupported.');
      return ModelRecommendationResult(
        badge: RecommendationBadge.unsupported,
        fileSizeGB: fileSizeGB,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: false,
        evidence: evidence,
      );
    }

    if (manifest.status == ModelSupportStatus.notRecommended) {
      evidence.add('A prior verified decision marked this model unsuitable.');
      return ModelRecommendationResult(
        badge: RecommendationBadge.highMemoryRisk,
        fileSizeGB: fileSizeGB,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: loadTested,
        evidence: evidence,
      );
    }

    if (fileSizeGB == null) {
      evidence.add('The installed file size is unavailable.');
      return ModelRecommendationResult(
        badge: RecommendationBadge.experimental,
        fileSizeGB: null,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: loadTested,
        evidence: evidence,
      );
    }

    evidence.add(
      'GGUF files occupy ${fileSizeGB.toStringAsFixed(2)} GiB; runtime RAM will be higher and depends on model architecture and context.',
    );
    if (manifest.quantization != null) {
      evidence.add('Manifest quantization: ${manifest.quantization}.');
    }
    if (manifest.contextLength != null) {
      evidence.add(
        'Manifest context limit: ${manifest.contextLength} tokens; a larger active context consumes additional memory.',
      );
    } else {
      evidence.add('Context-memory requirements are unknown.');
    }
    evidence.add(
      profile.hasGpuAcceleration == null
          ? 'No dependable accelerator capability was exposed; it is not used for this label.'
          : 'Runtime-reported accelerator availability: ${profile.hasGpuAcceleration! ? 'yes' : 'no'}.',
    );

    final thermal = profile.thermalState?.toLowerCase();
    if (const {'severe', 'critical', 'emergency', 'shutdown'}
        .contains(thermal)) {
      evidence.add('Current thermal state is $thermal.');
      return ModelRecommendationResult(
        badge: RecommendationBadge.highMemoryRisk,
        fileSizeGB: fileSizeGB,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: loadTested,
        evidence: evidence,
      );
    }

    if (availableRamGB == null || totalRamGB == null) {
      evidence.add('Current available or total RAM could not be measured.');
      return ModelRecommendationResult(
        badge: RecommendationBadge.experimental,
        fileSizeGB: fileSizeGB,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: loadTested,
        evidence: evidence,
      );
    }

    evidence.add(
      'Measured available RAM: ${availableRamGB.toStringAsFixed(2)} GiB of ${totalRamGB.toStringAsFixed(2)} GiB total.',
    );

    // File bytes are only a lower bound. Requiring generous headroom avoids
    // presenting a precise runtime-RAM formula the backend cannot substantiate.
    if (fileSizeGB > totalRamGB * 0.85 || fileSizeGB > availableRamGB * 0.80) {
      evidence
          .add('The weight file alone leaves insufficient measured headroom.');
      return ModelRecommendationResult(
        badge: RecommendationBadge.highMemoryRisk,
        fileSizeGB: fileSizeGB,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: loadTested,
        evidence: evidence,
      );
    }

    if (!loadTested) {
      evidence.add(
        'This exact model has not completed a load test on this device.',
      );
      return ModelRecommendationResult(
        badge: RecommendationBadge.experimental,
        fileSizeGB: fileSizeGB,
        availableRamGB: availableRamGB,
        loadTestedOnDevice: false,
        evidence: evidence,
      );
    }

    evidence.add(
      'This exact manifest previously completed a local load on this device.',
    );
    final badge = fileSizeGB <= availableRamGB * 0.60
        ? RecommendationBadge.recommended
        : RecommendationBadge.likelyCompatible;
    return ModelRecommendationResult(
      badge: badge,
      fileSizeGB: fileSizeGB,
      availableRamGB: availableRamGB,
      loadTestedOnDevice: true,
      evidence: evidence,
    );
  }
}
