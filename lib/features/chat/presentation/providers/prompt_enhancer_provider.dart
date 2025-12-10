import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class PromptEnhancerState {
  final String? selectedModelId;
  final bool isLoading;

  PromptEnhancerState({this.selectedModelId, this.isLoading = false});

  PromptEnhancerState copyWith({String? selectedModelId, bool? isLoading}) {
    return PromptEnhancerState(
      selectedModelId: selectedModelId ?? this.selectedModelId,
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
      final ollama = ref.read(ollamaServiceProvider);
      final enhanced = await ollama.enhancePrompt(
        model: modelId,
        userInput: input,
        systemPrompt: AppConstants.promptEnhancerSystemPrompt,
      );
      return enhanced;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final promptEnhancerProvider =
    NotifierProvider<PromptEnhancerNotifier, PromptEnhancerState>(
      PromptEnhancerNotifier.new,
    );
