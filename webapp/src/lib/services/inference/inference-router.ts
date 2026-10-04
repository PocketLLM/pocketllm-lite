/**
 * InferenceRouter — routes generation requests to the right runtime.
 *
 * Maintains one instance of each runtime; re-configures the
 * user-controlled ones (Ollama / OpenAI-compatible) from persisted
 * provider records before use. There is deliberately no hosted/built-in
 * model: every non-sandbox answer comes from a runtime the user configured.
 */
import type { ModelInfo, ChatTurn, GenerateOptions, GenerateResult, ConnectionTestResult } from './runtime';
import { InferenceRuntime } from './runtime';
import { OllamaRuntime } from './ollama-runtime';
import { OpenAICompatibleRuntime } from './openai-runtime';
import { MockRuntime } from './mock-runtime';
import { providerRepo } from '@/lib/core/db/repositories';
import { settingsService } from '@/lib/services/settings-service';
import type { RuntimeId } from '@/lib/types/domain';

class InferenceRouter {
  private runtimes: Map<RuntimeId, InferenceRuntime>;

  constructor() {
    this.runtimes = new Map<RuntimeId, InferenceRuntime>([
      ['ollama', new OllamaRuntime()],
      ['openai', new OpenAICompatibleRuntime()],
      ['mock', new MockRuntime()],
    ]);
  }

  get(id: RuntimeId): InferenceRuntime {
    // Defensive: data restored from an older backup may still name the
    // removed hosted runtime — resolve it to the offline sandbox.
    const runtime = this.runtimes.get(((id as string) === 'assist' ? 'mock' : id) as RuntimeId);
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

  /**
   * Picks the runtime for one-shot helper tasks (titles, prompt
   * enhancement, follow-ups, memory extraction). Preference order: the
   * caller's runtime, the default runtime, then any configured provider.
   * The offline sandbox is never used — it cannot do real work.
   * Returns null when the user has not connected a model yet.
   */
  async pickUtilityRuntime(preferred?: RuntimeId): Promise<RuntimeId | null> {
    await this.syncProviders();
    const providers = await providerRepo.getAll();
    const configured = new Set<RuntimeId>();
    if (providers.some((p) => p.type === 'ollama' && p.modelId)) configured.add('ollama');
    if (providers.some((p) => p.type === 'openai-compatible' && p.modelId)) configured.add('openai');
    const candidates: Array<RuntimeId | undefined> = [preferred, settingsService.get().chat.defaultRuntimeId, 'ollama', 'openai'];
    for (const id of candidates) {
      if (id && id !== 'mock' && configured.has(id)) return id;
    }
    return null;
  }

  async testConnection(runtimeId: RuntimeId): Promise<ConnectionTestResult> {
    await this.syncProviders();
    return this.get(runtimeId).testConnection();
  }
}

export const inferenceRouter = new InferenceRouter();
