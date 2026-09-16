/**
 * InferenceRouter — routes generation requests to the right runtime.
 *
 * Maintains one instance of each runtime; re-configures the
 * user-controlled ones (Ollama / OpenAI-compatible) from persisted
 * provider records before use.
 */
import type { ModelInfo, ChatTurn, GenerateOptions, GenerateResult, ConnectionTestResult } from './runtime';
import { InferenceRuntime } from './runtime';
import { AssistRuntime } from './assist-runtime';
import { OllamaRuntime } from './ollama-runtime';
import { OpenAICompatibleRuntime } from './openai-runtime';
import { MockRuntime } from './mock-runtime';
import { providerRepo } from '@/lib/core/db/repositories';
import type { RuntimeId } from '@/lib/types/domain';

class InferenceRouter {
  private runtimes: Map<RuntimeId, InferenceRuntime>;

  constructor() {
    this.runtimes = new Map<RuntimeId, InferenceRuntime>([
      ['assist', new AssistRuntime()],
      ['ollama', new OllamaRuntime()],
      ['openai', new OpenAICompatibleRuntime()],
      ['mock', new MockRuntime()],
    ]);
  }

  get(id: RuntimeId): InferenceRuntime {
    const runtime = this.runtimes.get(id);
    if (!runtime) throw new Error(`Unknown runtime: ${id}`);
    return runtime;
  }

  list(): InferenceRuntime[] {
    return [...this.runtimes.values()];
  }

  /**
   * Reconfigures the Ollama / OpenAI-compatible runtimes from the
   * latest persisted provider records. Called at boot and whenever
   * providers change.
   */
  async syncProviders(): Promise<void> {
    const providers = await providerRepo.getAll();
    const ollama = providers.find((p) => p.type === 'ollama');
    if (ollama) {
      (this.get('ollama') as OllamaRuntime).configure(
        ollama.baseUrl,
        ollama.modelId
      );
    }
    const openai = providers.find((p) => p.type === 'openai-compatible');
    if (openai) {
      (this.get('openai') as OpenAICompatibleRuntime).configure(
        openai.baseUrl,
        openai.apiKey ?? '',
        openai.modelId
      );
    }
  }

  /** All models across all runtimes for pickers. */
  async listAllModels(): Promise<ModelInfo[]> {
    const results = await Promise.allSettled(
      this.list().map((r) => r.listModels())
    );
    const models: ModelInfo[] = [];
    for (const r of results) {
      if (r.status === 'fulfilled') models.push(...r.value);
    }
    return models;
  }

  /** Convenience passthroughs. */
  async generate(
    runtimeId: RuntimeId,
    turns: ChatTurn[],
    options: GenerateOptions
  ): Promise<GenerateResult> {
    await this.syncProviders();
    return this.get(runtimeId).generate(turns, options);
  }

  async testConnection(runtimeId: RuntimeId): Promise<ConnectionTestResult> {
    await this.syncProviders();
    return this.get(runtimeId).testConnection();
  }
}

export const inferenceRouter = new InferenceRouter();
