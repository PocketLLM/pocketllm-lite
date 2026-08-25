enum ModelStoreRuntime { onDevice, speech, huggingFace, ollama }

class ModelStoreModel {
  final String id;
  final String name;
  final ModelStoreRuntime runtime;
  final int sizeMb;
  final String downloadUrl;
  final String archiveFilename;
  final int quantizationBits;
  final Set<String> capabilities;
  final String source;
  final String? license;

  const ModelStoreModel({
    required this.id,
    required this.name,
    required this.runtime,
    required this.sizeMb,
    required this.downloadUrl,
    required this.archiveFilename,
    required this.quantizationBits,
    required this.capabilities,
    required this.source,
    this.license,
  });

  bool get isEmbedding => capabilities.contains('Embeddings');
  bool get isSpeech => runtime == ModelStoreRuntime.speech;
}
