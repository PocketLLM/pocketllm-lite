enum SkillRiskLevel { low, medium, high }

class SkillPermissionManifest {
  final List<String> networkDomains;
  final List<String> readPaths;
  final List<String> writePaths;
  final List<String> deviceCapabilities;
  final SkillRiskLevel riskLevel;

  const SkillPermissionManifest({
    this.networkDomains = const [],
    this.readPaths = const [],
    this.writePaths = const [],
    this.deviceCapabilities = const [],
    this.riskLevel = SkillRiskLevel.low,
  });

  factory SkillPermissionManifest.fromFrontmatter(Map<String, dynamic> data) {
    final permissions = data['permissions'] as Map<String, dynamic>? ?? {};

    final network =
        (permissions['network'] as List?)?.map((e) => e.toString()).toList() ??
            [];
    final fs = permissions['filesystem'] as Map<String, dynamic>? ?? {};
    final read = (fs['read'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final write =
        (fs['write'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final device =
        (permissions['device'] as List?)?.map((e) => e.toString()).toList() ??
            [];

    SkillRiskLevel risk = SkillRiskLevel.low;
    final riskStr = (permissions['risk'] as String?)?.toLowerCase();
    if (riskStr == 'high' || network.length > 2 || write.isNotEmpty) {
      risk = SkillRiskLevel.high;
    } else if (riskStr == 'medium' || network.isNotEmpty || read.isNotEmpty) {
      risk = SkillRiskLevel.medium;
    }

    return SkillPermissionManifest(
      networkDomains: network,
      readPaths: read,
      writePaths: write,
      deviceCapabilities: device,
      riskLevel: risk,
    );
  }

  Map<String, dynamic> toJson() => {
        'networkDomains': networkDomains,
        'readPaths': readPaths,
        'writePaths': writePaths,
        'deviceCapabilities': deviceCapabilities,
        'riskLevel': riskLevel.name,
      };
}
