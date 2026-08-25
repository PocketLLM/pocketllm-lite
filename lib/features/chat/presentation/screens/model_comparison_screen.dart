import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';
import '../../../../services/generation_pipeline.dart';
import '../../../../services/inference_service.dart';
import '../providers/models_provider.dart';

class ComparisonResult {
  final String modelId;
  final String responseText;
  final Duration elapsed;
  final InferenceMetrics metrics;
  final Object? error;

  const ComparisonResult({
    required this.modelId,
    required this.responseText,
    required this.elapsed,
    required this.metrics,
    this.error,
  });
}

class ModelComparisonScreen extends ConsumerStatefulWidget {
  const ModelComparisonScreen({super.key});

  @override
  ConsumerState<ModelComparisonScreen> createState() =>
      _ModelComparisonScreenState();
}

class _ModelComparisonScreenState extends ConsumerState<ModelComparisonScreen> {
  final _promptController = TextEditingController(
    text: 'Explain quantum computing in simple terms for a 10 year old.',
  );
  String? _modelA;
  String? _modelB;
  bool _isComparing = false;
  ComparisonResult? _resultA;
  ComparisonResult? _resultB;
  String? _selectedWinner;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<ComparisonResult> _runOne(String modelId, String prompt) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await ref.read(generationPipelineProvider).complete(
            ChatRequest(
              modelId: modelId,
              messages: [
                ChatRequestMessage(role: 'user', content: prompt),
              ],
              temperature: 0.2,
              topP: 0.9,
              maxTokens: 256,
            ),
            options: const GenerationOptions(
              enableMemory: false,
              enableTools: false,
              contextLength: 2048,
            ),
          );
      stopwatch.stop();
      return ComparisonResult(
        modelId: modelId,
        responseText: result.text,
        elapsed: stopwatch.elapsed,
        metrics: result.metrics,
      );
    } catch (error) {
      stopwatch.stop();
      return ComparisonResult(
        modelId: modelId,
        responseText: '',
        elapsed: stopwatch.elapsed,
        metrics: const InferenceMetrics(),
        error: error,
      );
    }
  }

  Future<void> _runComparison() async {
    final prompt = _promptController.text.trim();
    final modelA = _modelA;
    final modelB = _modelB;
    if (prompt.isEmpty ||
        modelA == null ||
        modelB == null ||
        modelA == modelB) {
      return;
    }
    setState(() {
      _isComparing = true;
      _resultA = null;
      _resultB = null;
      _selectedWinner = null;
    });

    final first = await _runOne(modelA, prompt);
    final second = await _runOne(modelB, prompt);
    if (!mounted) return;
    setState(() {
      _resultA = first;
      _resultB = second;
      _isComparing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(unifiedModelsProvider);

    return Scaffold(
      appBar: const M3AppBar(title: 'A/B Model Comparison'),
      body: modelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load models: $error')),
        data: (models) {
          if (models.length < 2) {
            return const M3EmptyState(
              icon: Icons.compare_arrows_rounded,
              title: 'Two models are required',
              description:
                  'Install or connect at least two verified models before running a comparison.',
            );
          }
          _modelA = models.any((model) => model.id == _modelA)
              ? _modelA
              : models.first.id;
          _modelB =
              models.any((model) => model.id == _modelB) && _modelB != _modelA
                  ? _modelB
                  : models.firstWhere((model) => model.id != _modelA).id;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comparison prompt',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _promptController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Enter the same prompt for both models',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _modelPicker('Model A', _modelA!, models, (value) {
                        setState(() => _modelA = value);
                      }),
                      const SizedBox(height: 12),
                      _modelPicker('Model B', _modelB!, models, (value) {
                        setState(() => _modelB = value);
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isComparing || _modelA == _modelB
                              ? null
                              : _runComparison,
                          icon: _isComparing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.compare_arrows_rounded),
                          label: Text(
                            _isComparing
                                ? 'Running real inference…'
                                : 'Compare models',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_resultA != null && _resultB != null) ...[
                const SizedBox(height: 16),
                Text('Measured results', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _resultCard(_resultA!, theme, 'A'),
                const SizedBox(height: 8),
                _resultCard(_resultB!, theme, 'B'),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _modelPicker(
    String label,
    String value,
    List<UnifiedModel> models,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: models
          .map(
            (model) => DropdownMenuItem(
              value: model.id,
              child: Text('${model.name} · ${model.backend}'),
            ),
          )
          .toList(growable: false),
      onChanged: _isComparing
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
    );
  }

  Widget _resultCard(ComparisonResult result, ThemeData theme, String label) {
    final selected = _selectedWinner == result.modelId;
    final metrics = result.metrics;
    final tokenLabel = metrics.completionTokens <= 0
        ? 'Output tokens: unavailable'
        : 'Output tokens: ${metrics.completionTokens}${metrics.tokenCountsEstimated ? ' (estimated)' : ''}';
    return Card.outlined(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text('Model $label')),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.modelId,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (selected) const Icon(Icons.emoji_events_rounded),
              ],
            ),
            Text('Total latency: ${result.elapsed.inMilliseconds} ms'),
            Text(
              metrics.tokensPerSecond > 0
                  ? 'Output rate: ${metrics.tokensPerSecond.toStringAsFixed(1)} tokens/sec${metrics.tokenCountsEstimated ? ' (estimated tokens)' : ''}'
                  : 'Output rate: unavailable',
            ),
            Text(tokenLabel),
            const Divider(),
            SelectableText(
              result.error == null
                  ? (result.responseText.isEmpty
                      ? 'The model returned no text.'
                      : result.responseText)
                  : 'Inference failed: ${result.error}',
              maxLines: 12,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: result.error == null
                  ? () => setState(() => _selectedWinner = result.modelId)
                  : null,
              child: Text(selected ? 'Preferred result' : 'Prefer this result'),
            ),
          ],
        ),
      ),
    );
  }
}
