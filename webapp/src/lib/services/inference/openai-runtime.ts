/**
 * OpenAICompatibleRuntime — connects to any user-controlled
 * OpenAI-compatible endpoint (LM Studio, vLLM, llama.cpp server,
 * OpenRouter, …) using the standard `/v1/chat/completions` API with
 * SSE streaming.
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
import { gateway } from '@/lib/core/net/network-gateway';
import type { GenerationMetrics } from '@/lib/types/domain';

export class OpenAICompatibleRuntime extends InferenceRuntime {
  readonly id = 'openai' as const;
  readonly label = 'OpenAI-compatible';
  readonly description =
    'Connect an endpoint you control: LM Studio, vLLM, llama.cpp server or any OpenAI-style API.';
  readonly isLocal = false;
  readonly offlineCapable = false;
  supportsVision = false;

  constructor(
    private baseUrl: string = '',
    private apiKey: string = '',
    private modelId: string = ''
  ) {
    super();
  }

  configure(baseUrl: string, apiKey: string, modelId: string): void {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.apiKey = apiKey;
    this.modelId = modelId;
  }

  private endpoint(): string {
    // Append /v1/chat/completions unless the URL already ends with it.
    if (this.baseUrl.endsWith('/chat/completions')) return this.baseUrl;
    if (/\/v\d+$/.test(this.baseUrl)) {
      return `${this.baseUrl}/chat/completions`;
    }
    return `${this.baseUrl}/v1/chat/completions`;
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.apiKey) h.Authorization = `Bearer ${this.apiKey}`;
    return h;
  }

  async listModels(): Promise<ModelInfo[]> {
    if (!this.baseUrl) return [];
    try {
      const modelsUrl = this.baseUrl.endsWith('/chat/completions')
        ? this.baseUrl.replace(/chat\/completions$/, 'models')
        : `${this.baseUrl.replace(/\/v\d+$/, '')}/v1/models`;
      const res = await gateway.request('remote-inference', modelsUrl, {
        headers: this.headers(),
        signal: AbortSignal.timeout(8000),
      });
      if (!res.ok) return [];
      const json = (await res.json()) as { data?: Array<{ id: string }> };
      return (json.data ?? []).map((m) => ({
        id: m.id,
        label: m.id,
        runtimeId: 'openai' as const,
        supportsVision: false,
        supportsTools: true,
        supportsEmbeddings: true,
      }));
    } catch {
      return [];
    }
  }

  async testConnection(): Promise<ConnectionTestResult> {
    if (!this.baseUrl) {
      return { ok: false, message: 'Enter a base URL first.' };
    }
    try {
      const res = await gateway.request(
        'remote-inference',
        this.endpoint(),
        {
          method: 'POST',
          headers: this.headers(),
          body: JSON.stringify({
            model: this.modelId || 'gpt-3.5-turbo',
            messages: [{ role: 'user', content: 'ping' }],
            max_tokens: 1,
            stream: false,
          }),
          signal: AbortSignal.timeout(10_000),
        }
      );
      if (res.status === 401 || res.status === 403) {
        return {
          ok: false,
          message: 'The endpoint rejected the API key (401/403).',
        };
      }
      if (res.status === 404) {
        return {
          ok: false,
          message: `Endpoint not found at ${this.endpoint()}. Check the base URL (it should look like http://host:8000).`,
        };
      }
      if (!res.ok) {
        return { ok: false, message: `Endpoint returned HTTP ${res.status}.` };
      }
      return { ok: true, message: 'Endpoint is reachable and responded.' };
    } catch (err) {
      if (err instanceof Error && err.name === 'NetworkBlockedError') {
        return { ok: false, message: err.message };
      }
      return {
        ok: false,
        message: 'Could not reach the endpoint.',
        detail: 'Verify the server is running and allows cross-origin requests (CORS).',
      };
    }
  }

  async generate(turns: ChatTurn[], options: GenerateOptions): Promise<GenerateResult> {
    if (!this.baseUrl || !this.modelId) {
      throw new RuntimeUnavailableError(
        'No OpenAI-compatible provider configured yet. Add one in Providers.'
      );
    }
    const started = performance.now();
    let ttft: number | null = null;
    let content = '';

    const body = {
      model: this.modelId,
      stream: true,
      temperature: options.settings?.temperature,
      top_p: options.settings?.topP,
      max_tokens: options.settings?.maxTokens,
      messages: turns.map((t) => ({ role: t.role, content: t.content })),
    };

    let res: Response;
    try {
      res = await gateway.request('remote-inference', this.endpoint(), {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(body),
        signal: options.signal,
      });
    } catch (err) {
      if (options.signal?.aborted) throw new AbortedError();
      if (err instanceof Error && err.name === 'NetworkBlockedError') {
        throw new RuntimeUnavailableError(err.message);
      }
      throw new RuntimeUnavailableError('Endpoint unreachable. Open Providers to diagnose.');
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`Provider error (${res.status}): ${text.slice(0, 300)}`);
    }

    const contentType = res.headers.get('content-type') ?? '';
    if (contentType.includes('text/event-stream')) {
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
            if (!trimmed.startsWith('data:')) continue;
            const data = trimmed.slice(5).trim();
            if (!data || data === '[DONE]') continue;
            try {
              const frame = JSON.parse(data) as {
                choices?: Array<{ delta?: { content?: string } }>;
              };
              const delta = frame.choices?.[0]?.delta?.content ?? '';
              if (delta) {
                if (ttft === null) ttft = performance.now() - started;
                content += delta;
                options.onToken?.(delta);
              }
            } catch {
              /* skip */
            }
          }
        }
      } catch (err) {
        if (options.signal?.aborted) {
          return this.finish(content, started, ttft, true);
        }
        throw err;
      }
    } else {
      const json = (await res.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
        usage?: { prompt_tokens?: number; completion_tokens?: number };
      };
      content = json.choices?.[0]?.message?.content ?? '';
      if (content) {
        ttft = performance.now() - started;
        options.onToken?.(content);
      }
    }

    if (options.signal?.aborted) return this.finish(content, started, ttft, true);
    return this.finish(content, started, ttft, false);
  }

  private finish(
    content: string,
    started: number,
    ttft: number | null,
    cancelled: boolean
  ): GenerateResult {
    const durationMs = performance.now() - started;
    const tokensOut = this.estimateTokens(content);
    return {
      content,
      metrics: {
        ttftMs: ttft ?? undefined,
        durationMs,
        tokensOut,
        tokensPerSecond:
          !cancelled && durationMs > 0
            ? Math.round(tokensOut / (durationMs / 1000))
            : undefined,
      },
    };
  }
}
