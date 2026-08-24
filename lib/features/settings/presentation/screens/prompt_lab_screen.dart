import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/providers.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../../services/inference_service.dart';
import '../../../../services/model_profile_registry.dart';

class PromptLabScreen extends ConsumerStatefulWidget {
  const PromptLabScreen({super.key});

  @override
  ConsumerState<PromptLabScreen> createState() => _PromptLabScreenState();
}

class _PromptLabScreenState extends ConsumerState<PromptLabScreen> {
  final _systemPromptController = TextEditingController(
    text: 'You are an expert software engineer. Explain {{topic}} clearly.',
  );
  final _variableController = TextEditingController(text: 'Recursion in Dart');

  double _temperature = 0.6;
  double _topP = 0.95;
  String? _outputResult;
  bool _isRunning = false;

  Future<void> _runExperiment() async {
    final prompt = _systemPromptController.text
        .replaceAll('{{topic}}', _variableController.text.trim())
        .trim();
    if (prompt.isEmpty) return;

    setState(() => _isRunning = true);
    final model = ref.read(chatProvider).selectedModel;
    final output = StringBuffer();

    try {
      final stream = ref.read(generationPipelineProvider).stream(
            ChatRequest(
              modelId: model,
              messages: [ChatRequestMessage(role: 'user', content: prompt)],
              temperature: _temperature,
              topP: _topP,
            ),
          );
      await for (final token in stream) {
        output.write(token.text);
      }
      if (output.isEmpty) {
        throw StateError('The selected model returned no text.');
      }
      if (!mounted) return;
      setState(() {
        _outputResult =
            'Model: $model\nTemperature: $_temperature\nTop P: $_topP\n\n${output.toString()}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _outputResult = 'Experiment failed: $error';
      });
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _variableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model =
        ref.watch(chatProvider.select((state) => state.selectedModel));
    final profile = ModelProfileRegistry().getProfileForModel(model);

    return Scaffold(
      appBar: const M3AppBar(
        title: 'Prompt Lab',
        subtitle: 'Parameter Engineering & Template Benchmarks',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Model Profile Defaults',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Model: $model')),
                      Chip(label: Text('Family: ${profile.modelFamily}')),
                      Chip(
                          label:
                              Text('Chat Template: ${profile.chatTemplate}')),
                      Chip(label: Text('Context: ${profile.contextLength}')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _systemPromptController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'System Prompt Template (use {{variable}})',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _variableController,
            decoration: const InputDecoration(
              labelText: 'Variable {{topic}} Value',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Temperature: ${_temperature.toStringAsFixed(2)}'),
          Slider(
            value: _temperature,
            min: 0.0,
            max: 1.5,
            divisions: 15,
            onChanged: (val) => setState(() => _temperature = val),
          ),
          Text('Top P: ${_topP.toStringAsFixed(2)}'),
          Slider(
            value: _topP,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            onChanged: (val) => setState(() => _topP = val),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Run Model Experiment'),
            onPressed: _isRunning ? null : _runExperiment,
          ),
          if (_isRunning) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_outputResult != null) ...[
            const SizedBox(height: 24),
            Text(
              'Experiment Output',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _outputResult!,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
