/**
 * MockRuntime — deterministic, fully offline local runtime.
 *
 * Purpose (per the plan's Phase 2 exit condition): lets the entire
 * generation pipeline — state machine, streaming, cancellation,
 * tool-calling — be exercised with zero network and zero models.
 * It is honest: labelled "Offline sandbox" in the UI, never
 * pretending to be a real model.
 */
import type {
  ChatTurn,
  GenerateOptions,
  GenerateResult,
  ModelInfo,
} from './runtime';
import { InferenceRuntime } from './runtime';

const MOCK_MODELS: ModelInfo[] = [
  {
    id: 'mock-echo',
    label: 'Offline Sandbox',
    runtimeId: 'mock',
    detail: 'Deterministic · no network',
    supportsVision: false,
    supportsTools: true,
    supportsEmbeddings: false,
    contextLimit: 8192,
  },
];

export class MockRuntime extends InferenceRuntime {
  readonly id = 'mock' as const;
  readonly label = 'Offline Sandbox';
  readonly description =
    'Deterministic local runtime for testing the pipeline with no network and no model downloads.';
  readonly isLocal = true;
  readonly offlineCapable = true;

  async listModels(): Promise<ModelInfo[]> {
    return MOCK_MODELS;
  }

  async generate(turns: ChatTurn[], options: GenerateOptions): Promise<GenerateResult> {
    const started = performance.now();
    const lastUser = [...turns].reverse().find((t) => t.role === 'user');
    const prompt = lastUser?.content ?? '';

    // A small, deterministic "reasoned" reply that exercises markdown,
    // code blocks and streaming behavior in the UI.
    const reply = this.composeReply(prompt, turns);

    // Stream word-by-word, honoring cancellation between chunks.
    const words = reply.split(/(?<=\s)/);
    let content = '';
    for (const w of words) {
      if (options.signal?.aborted) break;
      await sleep(28);
      content += w;
      options.onToken?.(w);
    }

    const durationMs = performance.now() - started;
    return {
      content,
      metrics: {
        ttftMs: 28,
        durationMs,
        tokensOut: this.estimateTokens(content),
        tokensPerSecond: Math.round(this.estimateTokens(content) / (durationMs / 1000)) || 0,
      },
    };
  }

  private composeReply(prompt: string, turns: ChatTurn[]): string {
    const turnCount = turns.filter((t) => t.role !== 'system').length;
    const lines: string[] = [];

    lines.push(
      `**Offline Sandbox** replied deterministically — no network was used and no model ran.`
    );
    lines.push('');
    lines.push(`You said: “${prompt.slice(0, 240)}${prompt.length > 240 ? '…' : ''}”`);
    lines.push('');
    lines.push('This runtime exists so every pipeline feature can be tested offline:');
    lines.push('- streaming and the **Stop** button');
    lines.push('- message editing, regeneration and branching');
    lines.push('- tool-call cards (try `calculate 24*7.5` or `create a note about launch ideas`)');
    lines.push('- Strict Offline mode with network auditing');
    lines.push('');
    lines.push('Example markdown rendering:');
    lines.push('');
    lines.push('```ts');
    lines.push(`// conversation turn #${turnCount}`);
    lines.push(`const reply = await runtime.generate(turns, { signal });`);
    lines.push('```');
    lines.push('');
    lines.push(
      '> Switch to **PocketLLM Assist**, **Ollama** or a custom endpoint in the model picker for real answers.'
    );
    return lines.join('\n');
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
