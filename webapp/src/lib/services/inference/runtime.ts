/**
 * InferenceRuntime — the single interface the rest of PocketLLM uses
 * to talk to any model backend. The app never knows whether a
 * response came from the built-in Assist endpoint, Ollama, an
 * OpenAI-compatible server or the offline mock.
 */
import type { GenerationMetrics, GenerationSettings, RuntimeId } from '@/lib/types/domain';

export interface ModelInfo {
  id: string;
  label: string;
  runtimeId: RuntimeId;
  /** Short descriptor shown in selectors, e.g. "0.5B · Q4_K_M". */
  detail?: string;
  supportsVision: boolean;
  supportsTools: boolean;
  supportsEmbeddings: boolean;
  /** Context window in tokens, when the runtime reports one honestly. */
  contextLimit?: number | null;
}

export interface ChatTurn {
  role: 'system' | 'user' | 'assistant';
  content: string;
  /** Data-URL images for vision-capable runtimes. */
  images?: string[];
}

export interface ConnectionTestResult {
  ok: boolean;
  /** Human-readable diagnosis with fix guidance. */
  message: string;
  detail?: string;
}

export interface GenerateOptions {
  settings?: GenerationSettings;
  signal?: AbortSignal;
  onToken?: (delta: string) => void;
}

export interface GenerateResult {
  content: string;
  metrics: GenerationMetrics;
}

/**
 * Base class for all runtimes. Concrete runtimes implement
 * `listModels`, `generate` and optionally `testConnection`.
 */
export abstract class InferenceRuntime {
  abstract readonly id: RuntimeId;
  abstract readonly label: string;
  abstract readonly description: string;
  abstract readonly isLocal: boolean;
  /** True when this runtime can run without any network access. */
  abstract readonly offlineCapable: boolean;

  supportsVision = false;
  supportsTools = true;
  supportsEmbeddings = false;

  abstract listModels(): Promise<ModelInfo[]>;

  /**
   * Streams a completion. Implementations must:
   *  - honor `signal` promptly (abort mid-stream),
   *  - call `onToken` for each delta when streaming,
   *  - return metrics with at least duration.
   */
  abstract generate(turns: ChatTurn[], options: GenerateOptions): Promise<GenerateResult>;

  /** Optional connectivity test with plain-language diagnostics. */
  async testConnection(): Promise<ConnectionTestResult> {
    return { ok: true, message: 'No connection test required.' };
  }

  /** Rough token estimate helper shared by runtimes. */
  protected estimateTokens(text: string): number {
    return Math.ceil((text ?? '').length / 4);
  }
}

/** Thrown when the user aborts a generation. */
export class AbortedError extends Error {
  constructor() {
    super('Generation cancelled');
    this.name = 'AbortedError';
  }
}

/** Thrown when the network policy blocks a request. */
export class RuntimeUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'RuntimeUnavailableError';
  }
}
