class OllamaModelDetails {
  final String license;
  final String modelfile;
  final String parameters;
  final String template;
  final OllamaModelDetailsInfo details;

  OllamaModelDetails({
    required this.license,
    required this.modelfile,
    required this.parameters,
    required this.template,
    required this.details,
  });

  factory OllamaModelDetails.fromJson(Map<String, dynamic> json) {
    return OllamaModelDetails(
      license: json['license'] as String? ?? '',
      modelfile: json['modelfile'] as String? ?? '',
      parameters: json['parameters'] as String? ?? '',
      template: json['template'] as String? ?? '',
      details: OllamaModelDetailsInfo.fromJson(
        json['details'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class OllamaModelDetailsInfo {
  final String format;
  final String family;
  final List<String> families;
  final String parameterSize;
  final String quantizationLevel;

  OllamaModelDetailsInfo({
    required this.format,
    required this.family,
    required this.families,
    required this.parameterSize,
    required this.quantizationLevel,
  });

  factory OllamaModelDetailsInfo.fromJson(Map<String, dynamic> json) {
    return OllamaModelDetailsInfo(
      format: json['format'] as String? ?? '',
      family: json['family'] as String? ?? '',
      families: (json['families'] as List?)?.map((e) => e as String).toList() ?? [],
      parameterSize: json['parameter_size'] as String? ?? '',
      quantizationLevel: json['quantization_level'] as String? ?? '',
    );
  }
}
