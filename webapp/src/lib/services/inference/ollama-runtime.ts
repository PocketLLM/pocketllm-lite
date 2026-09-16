/**
 * OllamaRuntime — real client for a user-controlled Ollama server
 * (same device loopback or LAN). Streaming uses Ollama's native
 * NDJSON `/api/chat` endpoint. The connection wizard in Providers
 * surfaces the detailed diagnostics produced here.
 */
import {
  AbortedError,
  RuntimeUnavailableError,
  type ChatTurn,
  type ConnectionTestResult,
  type GenerateOptions,
  type GenerateResult,
  type ModelInfo,
} from './runtime';
import { InferenceRuntime } from './runtime';
import { gateway, classifyScope } from '@/lib/core/net/network-gateway';
import type { GenerationMetrics } from '@/lib/types/domain';

export class OllamaRuntime extends InferenceRuntime {
  readonly id = 'ollama' as const;
  readonly label = 'Ollama';
  readonly description =
    'Uses models already installed on your computer through a local Ollama server.';
  readonly isLocal = true;
  readonly offlineCapable = true;

  constructor(private baseUrl: string = 'http://127.0.0.1:11434', private modelId: string = '') {
    super();
  }

  configure(baseUrl: string, modelId: string): void {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.modelId = modelId;
  }

  private purpose(): 'ollama-loopback' | 'ollama-lan' {
    return classifyScope(this.baseUrl) === 'loopback'
      ? 'ollama-loopback'
      : 'ollama-lan';
  }

  async listModels(): Promise<ModelInfo[]> {
    try {
      const res = await gateway.request(this.purpose(), `${this.baseUrl}/api/tags`, {
        signal: AbortSignal.timeout(6000),
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const json = (await res.json()) as {
        models?: Array<{ name: string; details?: { parameter_size?: string } }>;
      };
      const base = (json.models ?? []).map((m) => ({
        id: m.name,
        label: m.name,
        runtimeId: 'ollama' as const,
        detail: m.details?.parameter_size,
        supportsVision: false,
        supportsTools: true,
        supportsEmbeddings: true,
      }));
      // Best-effort enrichment: /api/show per model carries the real
      // context window (model_info["<arch>.context_length"]). Knowing it
      // lets the composer/inspector context meters use the true window
      // instead of the honest 8k fallback. Failures just leave the field
      // unset — never blocks the listing.
      const enriched = await Promise.all(
        base.map(async (m) => ({
          ...m,
          contextLimit: await this.fetchContextLimit(m.id),
        }))
      );
      return enriched;
    } catch (err) {
      if (err instanceof Error && err.name === 'NetworkBlockedError') {
        throw new RuntimeUnavailableError(err.message);
      }
      // When Ollama is unreachable the model list is simply empty;
      // the Providers screen explains why.
      return [];
    }
  }

  /**
   * Queries Ollama's /api/show for a model's real context window.
   * Ollama nests it in model_info under an architecture-prefixed key
   * (e.g. "llama.context_length", "gemma2.context_length"), so any key
   * ending in .context_length is accepted. Returns null when the server
   * is slow, the shape changed, or the field is absent — callers treat
   * null as "assume 8k" (the honest fallback).
   */
  private async fetchContextLimit(model: string): Promise<number | null> {
    try {
      const res = await gateway.request(this.purpose(), `${this.baseUrl}/api/show`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model }),
        signal: AbortSignal.timeout(3000),
      });
      if (!res.ok) return null;
      const json = (await res.json()) as {
        model_info?: Record<string, unknown>;
      };
      for (const [key, value] of Object.entries(json.model_info ?? {})) {
        if (key.endsWith('.context_length') && typeof value === 'number' && value > 0) {
          return value;
        }
      }
      return null;
    } catch {
      return null;
    }
  }

  /**
   * Layered connection diagnostics, matching the plan's wizard:
   * host reachable → local network permission → origin accepted →
   * models installed.
   */
  async testConnection(): Promise<ConnectionTestResult> {
    const scope = classifyScope(this.baseUrl);
    if (this.baseUrl.startsWith('https://') && window.location.protocol === 'https:') {
      return {
        ok: false,
        message:
          'Mixed content blocked: this page is HTTPS but the Ollama URL is HTTP.',
        detail:
          'Browsers block HTTP requests from HTTPS pages. Serve PocketLLM over HTTP (e.g. localhost) or put Ollama behind an HTTPS proxy.',
      };
    }
    try {
      const res = await gateway.request(this.purpose(), `${this.baseUrl}/api/tags`, {
        signal: AbortSignal.timeout(6000),
      });
      if (res.status === 403 || res.status === 401) {
        return {
          ok: false,
          message: 'Ollama rejected this origin (CORS).',
          detail:
            'Start Ollama with OLLAMA_ORIGINS=* (or your PocketLLM origin) so the browser is allowed to talk to it, then retry.',
        };
      }
      if (!res.ok) {
        return {
          ok: false,
          message: `Ollama responded with HTTP ${res.status}.`,
        };
      }
      const json = (await res.json()) as { models?: unknown[] };
      const count = json.models?.length ?? 0;
      if (count === 0) {
        return {
          ok: true,
          message:
            'Ollama is reachable, but no models are installed yet. Run `ollama pull llama3.2` and refresh.',
        };
      }
      return {
        ok: true,
        message: `Ollama is reachable with ${count} model${count === 1 ? '' : 's'} (${scope}).`,
      };
    } catch (err) {
      if (err instanceof Error && err.name === 'NetworkBlockedError') {
        return { ok: false, message: err.message };
      }
      return {
        ok: false,
        message: 'Could not reach the Ollama server.',
        detail: `Make sure Ollama is running at ${this.baseUrl}. For LAN access, set OLLAMA_HOST=0.0.0.0 and OLLAMA_ORIGINS to this site's origin.`,
      };
    }
  }

  async generate(turns: ChatTurn[], options: GenerateOptions): Promise<GenerateResult> {
    if (!this.modelId) {
      throw new RuntimeUnavailableError(
        'No Ollama model selected. Pick one in Providers.'
      );
    }
    const started = performance.now();
    let ttft: number | null = null;
    let content = '';
    let promptTokens = 0;

    const body = {
      model: this.modelId,
      stream: true,
      options: {
        temperature: options.settings?.temperature,
        top_p: options.settings?.topP,
        num_predict: options.settings?.maxTokens,
      },
      messages: turns.map((t) => ({
        role: t.role,
        content: t.content,
        // Ollama vision: images as base64 without the data: prefix.
        ...(t.images?.length
          ? {
              images: t.images.map((u) => u.replace(/^data:[^,]+,/, '')),
            }
          : {}),
      })),
    };

    let res: Response;
    try {
      res = await gateway.request(this.purpose(), `${this.baseUrl}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: options.signal,
      });
    } catch (err) {
      if (options.signal?.aborted) throw new AbortedError();
      if (err instanceof Error && err.name === 'NetworkBlockedError') {
        throw new RuntimeUnavailableError(err.message);
      }
      throw new RuntimeUnavailableError(
        `Ollama at ${this.baseUrl} is unreachable. Open Providers to diagnose.`
      );
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      if (res.status === 404) {
        throw new RuntimeUnavailableError(
          `Model "${this.modelId}" is not installed on this Ollama server. Run \`ollama pull ${this.modelId}\`.`
        );
      }
      throw new Error(`Ollama error (${res.status}): ${text.slice(0, 300)}`);
    }

    // Parse NDJSON stream
    const reader = (res.body as ReadableStream<Uint8Array>).getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed) continue;
          try {
            const frame = JSON.parse(trimmed) as {
              message?: { content?: string };
              prompt_eval_count?: number;
              eval_count?: number;
              done?: boolean;
            };
            const delta = frame.message?.content ?? '';
            if (delta) {
              if (ttft === null) ttft = performance.now() - started;
              content += delta;
              options.onToken?.(delta);
            }
            if (frame.done) {
              promptTokens = frame.prompt_eval_count ?? 0;
              (this as { lastEval?: number }).lastEval = frame.eval_count ?? 0;
            }
          } catch {
            // skip malformed line
          }
        }
      }
    } catch (err) {
      if (options.signal?.aborted) {
        return this.finish(content, started, ttft, promptTokens, true);
      }
      throw err;
    }

    if (options.signal?.aborted) {
      return this.finish(content, started, ttft, promptTokens, true);
    }
    return this.finish(content, started, ttft, promptTokens, false);
  }

  private lastMetrics: GenerationMetrics = {};

  private finish(
    content: string,
    started: number,
    ttft: number | null,
    promptTokens: number,
    cancelled: boolean
  ): GenerateResult {
    const durationMs = performance.now() - started;
    const tokensOut =
      (this as unknown as { lastEval?: number }).lastEval || this.estimateTokens(content);
    const metrics: GenerationMetrics = {
      ttftMs: ttft ?? undefined,
      durationMs,
      tokensIn: promptTokens || undefined,
      tokensOut,
      tokensPerSecond:
        !cancelled && durationMs > 0
          ? Math.round(tokensOut / (durationMs / 1000))
          : undefined,
    };
    return { content, metrics };
  }
}
