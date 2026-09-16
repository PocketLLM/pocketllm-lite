/**
 * AssistRuntime — the built-in PocketLLM Assist runtime.
 *
 * Streams completions through this app's own `/api/chat` endpoint
 * (which is the only place z-ai-web-dev-sdk is ever touched). All
 * requests go through the NetworkGateway so Strict Offline and the
 * network audit apply uniformly.
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

const ASSIST_MODELS: ModelInfo[] = [
  {
    id: 'pocketllm-assist',
    label: 'PocketLLM Assist',
    runtimeId: 'assist',
    detail: 'Balanced · always available',
    supportsVision: true,
    supportsTools: true,
    supportsEmbeddings: false,
    contextLimit: 128_000,
  },
];

/** Parsed SSE chunk from the server (OpenAI-style `data:` lines). */
interface SSEFrame {
  choices?: Array<{
    delta?: { content?: string | null };
    message?: { content?: string | null };
  }>;
}

export class AssistRuntime extends InferenceRuntime {
  readonly id = 'assist' as const;
  readonly label = 'PocketLLM Assist';
  readonly description =
    'Built-in assistant hosted by this app. Works everywhere; needs the network.';
  readonly isLocal = false;
  readonly offlineCapable = false;
  supportsVision = true;

  async listModels(): Promise<ModelInfo[]> {
    return ASSIST_MODELS;
  }

  async testConnection(): Promise<ConnectionTestResult> {
    try {
      const res = await gateway.request('assist-inference', '/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [{ role: 'user', content: 'ping' }],
          stream: false,
        }),
      });
      if (!res.ok) {
        return { ok: false, message: `Assist endpoint returned ${res.status}` };
      }
      return { ok: true, message: 'Assist runtime is reachable.' };
    } catch (err) {
      const blocked = err instanceof Error && err.name === 'NetworkBlockedError';
      return {
        ok: false,
        message: blocked
          ? 'Strict Offline is enabled — the built-in Assist runtime is blocked.'
          : 'Assist endpoint is unreachable.',
        detail: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async generate(turns: ChatTurn[], options: GenerateOptions): Promise<GenerateResult> {
    const started = performance.now();
    let ttft: number | null = null;

    // Vision path: images present → /api/vision with multimodal content.
    const hasImages = turns.some((t) => t.images?.length);

    const body = hasImages
      ? {
          stream: true,
          messages: turns.map((t) => ({
            role: t.role,
            content: [
              { type: 'text', text: t.content },
              ...(t.images ?? []).map((url) => ({
                type: 'image_url',
                image_url: { url },
              })),
            ],
          })),
        }
      : {
          stream: true,
          temperature: options.settings?.temperature,
          top_p: options.settings?.topP,
          max_tokens: options.settings?.maxTokens,
          messages: turns.map((t) => ({ role: t.role, content: t.content })),
        };

    let res: Response;
    try {
      res = await gateway.request(
        'assist-inference',
        hasImages ? '/api/vision' : '/api/chat',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
          signal: options.signal,
        }
      );
    } catch (err) {
      if (options.signal?.aborted) throw new AbortedError();
      if (err instanceof Error && err.name === 'NetworkBlockedError') {
        throw new RuntimeUnavailableError(err.message);
      }
      throw err;
    }

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`Assist failed (${res.status}): ${text.slice(0, 300)}`);
    }

    const contentType = res.headers.get('content-type') ?? '';
    let content = '';

    if (contentType.includes('text/event-stream') || contentType.includes('text/plain')) {
      // ---- Parse SSE stream ----
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
              const frame = JSON.parse(data) as SSEFrame;
              const delta =
                frame.choices?.[0]?.delta?.content ??
                frame.choices?.[0]?.message?.content ??
                '';
              if (delta) {
                if (ttft === null) ttft = performance.now() - started;
                content += delta;
                options.onToken?.(delta);
              }
            } catch {
              // Ignore malformed frame.
            }
          }
        }
      } catch (err) {
        if (options.signal?.aborted) {
          // The user stopped; keep what streamed so far.
          return this.finish(content, started, ttft, true);
        }
        throw err;
      }
    } else {
      // ---- Non-streaming JSON fallback ----
      const json = (await res.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };
      content = json.choices?.[0]?.message?.content ?? '';
      if (content) {
        ttft = performance.now() - started;
        options.onToken?.(content);
      }
    }

    if (options.signal?.aborted) {
      return this.finish(content, started, ttft, true);
    }
    return this.finish(content, started, ttft, false);
  }

  private finish(
    content: string,
    started: number,
    ttft: number | null,
    cancelled: boolean
  ): GenerateResult {
    const durationMs = performance.now() - started;
    const metrics: GenerationMetrics = {
      ttftMs: ttft ?? undefined,
      durationMs,
      tokensIn: undefined,
      tokensOut: this.estimateTokens(content),
      tokensPerSecond: undefined,
    };
    if (!cancelled && durationMs > 0) {
      metrics.tokensPerSecond = Math.round(
        (metrics.tokensOut ?? 0) / (durationMs / 1000)
      );
    }
    return { content, metrics };
  }
}
