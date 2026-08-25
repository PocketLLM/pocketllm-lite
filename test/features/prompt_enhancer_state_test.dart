import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/prompt_enhancer_provider.dart';

void main() {
  test('enhancer selection can be explicitly disabled', () {
    final selected = PromptEnhancerState(selectedModelId: 'model-a');

    final disabled = selected.copyWith(selectedModelId: null);

    expect(disabled.selectedModelId, isNull);
  });
}
