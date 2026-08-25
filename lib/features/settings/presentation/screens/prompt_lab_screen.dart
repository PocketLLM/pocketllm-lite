import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';
import '../../../../services/generation_pipeline.dart';
import '../../../../services/inference_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/providers/models_provider.dart';

class PromptLabScreen extends ConsumerStatefulWidget {
  const PromptLabScreen({super.key});

  @override
  ConsumerState<PromptLabScreen> createState() => _PromptLabScreenState();
}

class _PromptLabScreenState extends ConsumerState<PromptLabScreen> {
  final _systemPromptController = TextEditingController(
    text: 'You are an expert software engineer. Explain concepts clearly.',
  );
  final _userPromptController = TextEditingController(
    text: 'Explain {{topic}} with a concise example.',
  );
  final _variableController = TextEditingController(text: 'recursion in Dart');
  double _temperature = 0.6;
  double _topP = 0.95;
  int _topK = 40;
  int _maxTokens = 512;
  String? _selectedModel;
  String? _outputResult;
  bool _isRunning = false;

  @override
  void dispose() {
    _systemPromptController.dispose();
    _userPromptController.dispose();
    _variableController.dispose();
    super.dispose();
  }

  Future<void> _runExperiment() async {
    final model = _selectedModel;
    final userPrompt = _userPromptController.text
        .replaceAll('{{topic}}', _variableController.text.trim())
        .trim();
    if (model == null || userPrompt.isEmpty) return;
    setState(() => _isRunning = true);
    final stopwatch = Stopwatch()..start();
    try {
      final result = await ref.read(generationPipelineProvider).complete(
            ChatRequest(
              modelId: model,
              systemPrompt: _systemPromptController.text.trim(),
              messages: [
                ChatRequestMessage(role: 'user', content: userPrompt),
              ],
              temperature: _temperature,
              topP: _topP,
              topK: _topK,
              maxTokens: _maxTokens,
            ),
            options: const GenerationOptions(
              enableMemory: false,
              enableTools: false,
              contextLength: 2048,
            ),
          );
      stopwatch.stop();
      final metrics = result.metrics;
      final tokenText = metrics.completionTokens > 0
          ? '${metrics.completionTokens}${metrics.tokenCountsEstimated ? ' estimated' : ' measured'} output tokens'
          : 'output token count unavailable';
      final rateText = metrics.tokensPerSecond > 0
          ? '${metrics.tokensPerSecond.toStringAsFixed(1)} tokens/sec${metrics.tokenCountsEstimated ? ' (estimated token count)' : ''}'
          : 'token speed unavailable';
      if (!mounted) return;
      setState(() {
        _outputResult = 'Model: $model\n'
            'Latency: ${stopwatch.elapsedMilliseconds} ms\n'
            'Metrics: $tokenText · $rateText\n'
            'Parameters applied: temperature $_temperature, top_p $_topP, top_k $_topK, max_tokens $_maxTokens\n\n'
            '${result.text}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _outputResult = 'Experiment failed: $error');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(unifiedModelsProvider);
    final chatModel =
        ref.watch(chatProvider.select((state) => state.selectedModel));

    return Scaffold(
      appBar: const M3AppBar(
        title: 'Prompt Lab',
        subtitle: 'Run real prompts with supported parameters',
      ),
      body: modelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load models: $error')),
        data: (models) {
          if (models.isEmpty) {
            return const M3EmptyState(
              icon: Icons.science_outlined,
              title: 'No runnable model',
              description:
                  'Install a local model or connect a provider before using Prompt Lab.',
            );
          }
          _selectedModel = models.any((model) => model.id == _selectedModel)
              ? _selectedModel
              : models.any((model) => model.id == chatModel)
                  ? chatModel
                  : models.first.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedModel,
                decoration: const InputDecoration(labelText: 'Model'),
                items: models
                    .map(
                      (model) => DropdownMenuItem(
                        value: model.id,
                        child: Text('${model.name} · ${model.backend}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isRunning
                    ? null
                    : (value) => setState(() => _selectedModel = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _systemPromptController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'System prompt'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userPromptController,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'User prompt template',
                  helperText: 'Use {{topic}} to insert the variable below.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _variableController,
                decoration: const InputDecoration(labelText: '{{topic}} value'),
              ),
              const SizedBox(height: 16),
              Text('Temperature: ${_temperature.toStringAsFixed(2)}'),
              Slider(
                value: _temperature,
                min: 0,
                max: 1.5,
                divisions: 30,
                onChanged: _isRunning
                    ? null
                    : (value) => setState(() => _temperature = value),
              ),
              Text('Top P: ${_topP.toStringAsFixed(2)}'),
              Slider(
                value: _topP,
                min: 0.1,
                max: 1,
                divisions: 18,
                onChanged: _isRunning
                    ? null
                    : (value) => setState(() => _topP = value),
              ),
              Text('Top K: $_topK'),
              Slider(
                value: _topK.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: _isRunning
                    ? null
                    : (value) => setState(() => _topK = value.round()),
              ),
              Text('Max tokens: $_maxTokens'),
              Slider(
                value: _maxTokens.toDouble(),
                min: 64,
                max: 2048,
                divisions: 31,
                onChanged: _isRunning
                    ? null
                    : (value) => setState(() => _maxTokens = value.round()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isRunning ? null : _runExperiment,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_isRunning ? 'Running…' : 'Run experiment'),
              ),
              if (_isRunning) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_outputResult != null) ...[
                const SizedBox(height: 24),
                Text('Experiment output', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _outputResult!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
