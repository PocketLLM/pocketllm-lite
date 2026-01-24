import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/providers.dart';
import '../../../chat/domain/models/ollama_model_details.dart';

class ModelDetailsDialog extends ConsumerStatefulWidget {
  final String modelName;

  const ModelDetailsDialog({
    super.key,
    required this.modelName,
  });

  @override
  ConsumerState<ModelDetailsDialog> createState() => _ModelDetailsDialogState();
}

class _ModelDetailsDialogState extends ConsumerState<ModelDetailsDialog> {
  late Future<OllamaModelDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = ref.read(ollamaServiceProvider).getModelDetails(widget.modelName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.modelName} Specs'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for scrolling
        child: FutureBuilder<OllamaModelDetails>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData) {
              return const Center(child: Text('No details available'));
            }

            final details = snapshot.data!;
            final info = details.details;

            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'License'),
                      Tab(text: 'Template'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Overview Tab
                        ListView(
                          padding: const EdgeInsets.only(top: 16),
                          children: [
                            _buildDetailRow('Family', info.family),
                            _buildDetailRow('Parameters', info.parameterSize),
                            _buildDetailRow('Quantization', info.quantizationLevel),
                            _buildDetailRow('Format', info.format),
                            if (info.families.isNotEmpty)
                              _buildDetailRow('Families', info.families.join(', ')),
                            if (details.parameters.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Parameters', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  details.parameters,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // License Tab
                        Markdown(
                          data: details.license.isEmpty ? 'No license provided.' : details.license,
                          padding: const EdgeInsets.only(top: 16),
                        ),
                        // Template Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              details.template.isEmpty ? 'No template provided.' : details.template,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
