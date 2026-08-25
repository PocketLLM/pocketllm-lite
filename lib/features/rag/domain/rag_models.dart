enum RagRetrievalMode {
  keyword,
  semantic,
  hybrid;

  String get label => switch (this) {
        keyword => 'Keyword',
        semantic => 'Semantic',
        hybrid => 'Hybrid',
      };

  String get description => switch (this) {
        keyword => 'Fast BM25 search. No embedding model required.',
        semantic =>
          'Meaning-based cosine search using a local embedding model.',
        hybrid => 'Combines keyword and semantic scores for stronger recall.',
      };

  bool get requiresEmbedding => this != keyword;

  static RagRetrievalMode parse(String? value) => values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => RagRetrievalMode.keyword,
      );
}

class EmbeddingModelOption {
  final String id;
  final String name;
  final int catalogSizeMb;
  final String summary;

  const EmbeddingModelOption({
    required this.id,
    required this.name,
    required this.catalogSizeMb,
    required this.summary,
  });
}

const supportedEmbeddingModels = <EmbeddingModelOption>[
  EmbeddingModelOption(
    id: 'qwen3-0.6-embed',
    name: 'Qwen3 Embedding 0.6B',
    catalogSizeMb: 394,
    summary: 'Multilingual embedding model from the Cactus catalog.',
  ),
  EmbeddingModelOption(
    id: 'nomic2-embed-300m',
    name: 'Nomic Embed Text v2 MoE',
    catalogSizeMb: 533,
    summary: 'Multilingual retrieval model from the Cactus catalog.',
  ),
];

class RagSetupStatus {
  final RagRetrievalMode mode;
  final String? embeddingModelId;
  final bool embeddingModelInstalled;

  const RagSetupStatus({
    required this.mode,
    required this.embeddingModelId,
    required this.embeddingModelInstalled,
  });

  bool get ready => !mode.requiresEmbedding || embeddingModelInstalled;
}
