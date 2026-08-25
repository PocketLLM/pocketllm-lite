import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../services/generation_pipeline.dart';
import '../../../../services/inference_service.dart';

class PromptEnhancerState {
  static const _unset = Object();
  final String? selectedModelId;
  final bool isLoading;

  PromptEnhancerState({this.selectedModelId, this.isLoading = false});

  PromptEnhancerState copyWith({
    Object? selectedModelId = _unset,
    bool? isLoading,
  }) {
    return PromptEnhancerState(
      selectedModelId: identical(selectedModelId, _unset)
          ? this.selectedModelId
          : selectedModelId as String?,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PromptEnhancerNotifier extends Notifier<PromptEnhancerState> {
  @override
  PromptEnhancerState build() {
    final storage = ref.read(storageServiceProvider);
    final savedModelId = storage.getSetting(
      AppConstants.promptEnhancerModelKey,
      defaultValue: null,
    );
    return PromptEnhancerState(selectedModelId: savedModelId);
  }

  Future<void> setSelectedModel(String? modelId) async {
    state = state.copyWith(selectedModelId: modelId);
    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.promptEnhancerModelKey, modelId);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  Future<String> enhancePrompt(String input) async {
    final modelId = state.selectedModelId;
    if (modelId == null || modelId.isEmpty) {
      throw Exception('No enhancer model selected');
    }

    state = state.copyWith(isLoading: true);
    try {
      final result = await ref.read(generationPipelineProvider).complete(
            ChatRequest(
              modelId: modelId,
              messages: [ChatRequestMessage(role: 'user', content: input)],
              systemPrompt: AppConstants.promptEnhancerSystemPrompt,
              temperature: 0.2,
              topP: 0.8,
              maxTokens: 768,
            ),
            options: const GenerationOptions(
              enableMemory: false,
              enableTools: false,
              contextLength: 2048,
            ),
          );
      return result.text;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final promptEnhancerProvider =
    NotifierProvider<PromptEnhancerNotifier, PromptEnhancerState>(
  PromptEnhancerNotifier.new,
);
