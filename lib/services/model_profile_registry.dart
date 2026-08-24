class ModelProfile {
  final String modelFamily;
  final String chatTemplate;
  final double temperature;
  final double topP;
  final int topK;
  final double repeatPenalty;
  final int contextLength;
  final bool supportsTools;
  final bool supportsThinking;
  final String? bosToken;
  final String? eosToken;
  final List<String> stopSequences;
  final String? thinkingTagStart;
  final String? thinkingTagEnd;

  const ModelProfile({
    required this.modelFamily,
    required this.chatTemplate,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.repeatPenalty,
    required this.contextLength,
    required this.supportsTools,
    required this.supportsThinking,
    this.bosToken,
    this.eosToken,
    required this.stopSequences,
    this.thinkingTagStart,
    this.thinkingTagEnd,
  });

  Map<String, dynamic> toJson() => {
        'modelFamily': modelFamily,
        'chatTemplate': chatTemplate,
        'temperature': temperature,
        'topP': topP,
        'topK': topK,
        'repeatPenalty': repeatPenalty,
        'contextLength': contextLength,
        'supportsTools': supportsTools,
        'supportsThinking': supportsThinking,
        'bosToken': bosToken,
        'eosToken': eosToken,
        'stopSequences': stopSequences,
        'thinkingTagStart': thinkingTagStart,
        'thinkingTagEnd': thinkingTagEnd,
      };
}

class ModelProfileRegistry {
  static final ModelProfileRegistry _instance =
      ModelProfileRegistry._internal();
  factory ModelProfileRegistry() => _instance;
  ModelProfileRegistry._internal();

  final Map<String, ModelProfile> _profiles = {
    'qwen': const ModelProfile(
      modelFamily: 'Qwen',
      chatTemplate: 'qwen',
      temperature: 0.6,
      topP: 0.95,
      topK: 20,
      repeatPenalty: 1.05,
      contextLength: 8192,
      supportsTools: true,
      supportsThinking: true,
      bosToken: '<|im_start|>',
      eosToken: '<|im_end|>',
      stopSequences: ['<|im_end|>', '<|endoftext|>'],
      thinkingTagStart: '<think>',
      thinkingTagEnd: '</think>',
    ),
    'deepseek': const ModelProfile(
      modelFamily: 'DeepSeek R1',
      chatTemplate: 'deepseek-r1',
      temperature: 0.6,
      topP: 0.95,
      topK: 40,
      repeatPenalty: 1.10,
      contextLength: 16384,
      supportsTools: false,
      supportsThinking: true,
      bosToken: '<｜begin of sentence｜>',
      eosToken: '<｜end of sentence｜>',
      stopSequences: ['<｜end of sentence｜>', '<|endoftext|>'],
      thinkingTagStart: '<think>',
      thinkingTagEnd: '</think>',
    ),
    'llama': const ModelProfile(
      modelFamily: 'Llama 3',
      chatTemplate: 'llama3',
      temperature: 0.7,
      topP: 0.90,
      topK: 40,
      repeatPenalty: 1.10,
      contextLength: 8192,
      supportsTools: true,
      supportsThinking: false,
      bosToken: '<|begin_of_text|>',
      eosToken: '<|eot_id|>',
      stopSequences: ['<|eot_id|>', '<|end_of_text|>'],
    ),
    'mistral': const ModelProfile(
      modelFamily: 'Mistral',
      chatTemplate: 'mistral',
      temperature: 0.7,
      topP: 0.90,
      topK: 40,
      repeatPenalty: 1.15,
      contextLength: 8192,
      supportsTools: true,
      supportsThinking: false,
      bosToken: '<s>',
      eosToken: '</s>',
      stopSequences: ['</s>'],
    ),
    'gemma': const ModelProfile(
      modelFamily: 'Gemma 2',
      chatTemplate: 'gemma',
      temperature: 0.8,
      topP: 0.90,
      topK: 40,
      repeatPenalty: 1.05,
      contextLength: 8192,
      supportsTools: false,
      supportsThinking: false,
      bosToken: '<bos>',
      eosToken: '<eos>',
      stopSequences: ['<eos>', '<end_of_turn>'],
    ),
  };

  ModelProfile getProfileForModel(String modelId) {
    final lower = modelId.toLowerCase();

    if (lower.contains('qwen')) return _profiles['qwen']!;
    if (lower.contains('deepseek') || lower.contains('r1')) {
      return _profiles['deepseek']!;
    }
    if (lower.contains('llama')) return _profiles['llama']!;
    if (lower.contains('mistral') || lower.contains('mixtral')) {
      return _profiles['mistral']!;
    }
    if (lower.contains('gemma')) return _profiles['gemma']!;

    // Generic default
    return ModelProfile(
      modelFamily: 'Generic GGUF',
      chatTemplate: 'chatml',
      temperature: 0.7,
      topP: 0.90,
      topK: 40,
      repeatPenalty: 1.10,
      contextLength: 4096,
      supportsTools: lower.contains('tool') || lower.contains('function'),
      supportsThinking: lower.contains('think') || lower.contains('reasoning'),
      stopSequences: ['<|im_end|>', '</s>'],
    );
  }
}
