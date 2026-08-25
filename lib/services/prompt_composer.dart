class PromptLayer {
  final String name;
  final String content;

  const PromptLayer({required this.name, required this.content});
}

class PromptComposer {
  const PromptComposer();

  String compose({
    String? basePolicy,
    String? modelInstructions,
    String? persona,
    Iterable<String> skills = const [],
    String? toolInstructions,
    String? memoryContext,
    String? documentContext,
  }) {
    final layers = <PromptLayer>[
      if (_present(basePolicy))
        PromptLayer(name: 'Base assistant policy', content: basePolicy!.trim()),
      if (_present(modelInstructions))
        PromptLayer(
          name: 'Model instructions',
          content: modelInstructions!.trim(),
        ),
      if (_present(persona))
        PromptLayer(name: 'Persona', content: persona!.trim()),
      for (final skill in skills.where(_present))
        PromptLayer(name: 'Active skill', content: skill.trim()),
      if (_present(toolInstructions))
        PromptLayer(name: 'Tool schemas', content: toolInstructions!.trim()),
      if (_present(memoryContext))
        PromptLayer(name: 'Relevant memory', content: memoryContext!.trim()),
      if (_present(documentContext))
        PromptLayer(
          name: 'Retrieved documents',
          content: documentContext!.trim(),
        ),
    ];

    return layers
        .map((layer) => '## ${layer.name}\n${layer.content}')
        .join('\n\n');
  }

  bool _present(String? value) => value != null && value.trim().isNotEmpty;
}
