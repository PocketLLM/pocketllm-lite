import { db, logActivity, logError } from "../db/db";
import { networkFetch } from "./network";
import { readOpfs } from "./storage";
import type { BrowserModel, Provider, RuntimeCapabilities, RuntimeKind } from "./types";

export interface RuntimeMessage {
  role: "system" | "user" | "assistant";
  content: string;
  images?: string[];
}

export interface GenerateRequest {
  messages: RuntimeMessage[];
  signal: AbortSignal;
  onToken: (token: string) => void;
  maxTokens?: number;
  temperature?: number;
  topP?: number;
  topK?: number;
}

export interface RuntimeAdapter {
  id: RuntimeKind;
  label: string;
  capabilities: RuntimeCapabilities;
  modelName: string;
  generate(request: GenerateRequest): Promise<void>;
  test(): Promise<string[]>;
  unload?(): Promise<void>;
}

function normalizeBaseUrl(baseUrl: string) {
  return baseUrl.trim().replace(/\/+$/, "");
}

async function consumeSse(
  response: Response,
  pick: (payload: unknown) => string | undefined,
  onToken: (token: string) => void,
  signal: AbortSignal,
) {
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(body || `Request failed with HTTP ${response.status}`);
  }
  if (!response.body) throw new Error("Streaming response had no body.");

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    if (signal.aborted) {
      await reader.cancel().catch(() => undefined);
      throw new DOMException("Generation stopped", "AbortError");
    }
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const raw of lines) {
      const line = raw.trim();
      if (!line || !line.startsWith("data:")) continue;
      const data = line.slice(5).trim();
      if (data === "[DONE]") return;
      try {
        const token = pick(JSON.parse(data));
        if (token) onToken(token);
      } catch {
        // A malformed event line is isolated; later SSE events are still valid.
      }
    }
  }
}

export function providerRuntime(provider: Provider): RuntimeAdapter {
  const secret = () => sessionStorage.getItem(`provider-key:${provider.id}`) ?? undefined;
  const purpose = provider.kind === "ollama"
    ? normalizeBaseUrl(provider.baseUrl).includes("127.0.0.1") || normalizeBaseUrl(provider.baseUrl).includes("localhost")
      ? "ollama-loopback" as const
      : "ollama-lan" as const
    : "remote-inference" as const;

  if (provider.kind === "ollama") {
    return {
      id: "ollama",
      label: provider.name,
      capabilities: provider.capabilities,
      modelName: provider.model,
      async test() {
        const response = await networkFetch(`${normalizeBaseUrl(provider.baseUrl)}/api/tags`, {}, "provider-test");
        if (!response.ok) throw new Error(`Ollama returned HTTP ${response.status}`);
        const data = (await response.json()) as { models?: Array<{ name?: string }> };
        return (data.models ?? []).flatMap((item) => item.name ? [item.name] : []);
      },
      async generate({ messages, signal, onToken, maxTokens, temperature, topP, topK }) {
        const response = await networkFetch(
          `${normalizeBaseUrl(provider.baseUrl)}/api/chat`,
          {
            method: "POST",
            signal,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              model: provider.model,
              stream: true,
              messages,
              options: {
                ...(typeof maxTokens === "number" ? { num_predict: maxTokens } : {}),
                ...(typeof temperature === "number" ? { temperature } : {}),
                ...(typeof topP === "number" ? { top_p: topP } : {}),
                ...(typeof topK === "number" ? { top_k: topK } : {}),
              },
            }),
          },
          purpose,
        );
        if (!response.ok) {
          const body = await response.text().catch(() => "");
          throw new Error(body || `Ollama returned HTTP ${response.status}`);
        }
        if (!response.body) throw new Error("Ollama streaming response had no body.");
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        while (true) {
          if (signal.aborted) {
            await reader.cancel().catch(() => undefined);
            throw new DOMException("Generation stopped", "AbortError");
          }
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() ?? "";
          for (const line of lines) {
            if (!line.trim()) continue;
            const event = JSON.parse(line) as { message?: { content?: string }; done?: boolean; error?: string };
            if (event.error) throw new Error(event.error);
            if (event.message?.content) onToken(event.message.content);
            if (event.done) return;
          }
        }
      },
    };
  }

  return {
    id: "openai-compatible",
    label: provider.name,
    capabilities: provider.capabilities,
    modelName: provider.model,
    async test() {
      const response = await networkFetch(
        `${normalizeBaseUrl(provider.baseUrl)}/models`,
        { headers: secret() ? { Authorization: `Bearer ${secret()}` } : undefined },
        "provider-test",
      );
      if (!response.ok) throw new Error(`Provider returned HTTP ${response.status}`);
      const data = (await response.json()) as { data?: Array<{ id?: string }> };
      return (data.data ?? []).flatMap((item) => item.id ? [item.id] : []);
    },
    async generate({ messages, signal, onToken, maxTokens, temperature, topP }) {
      const response = await networkFetch(
        `${normalizeBaseUrl(provider.baseUrl)}/chat/completions`,
        {
          method: "POST",
          signal,
          headers: {
            "Content-Type": "application/json",
            ...(secret() ? { Authorization: `Bearer ${secret()}` } : {}),
          },
          body: JSON.stringify({
            model: provider.model,
            stream: true,
            messages,
            ...(typeof maxTokens === "number" ? { max_tokens: maxTokens } : {}),
            ...(typeof temperature === "number" ? { temperature } : {}),
            ...(typeof topP === "number" ? { top_p: topP } : {}),
          }),
        },
        "remote-inference",
      );
      await consumeSse(
        response,
        (payload) => {
          const event = payload as { choices?: Array<{ delta?: { content?: string } }> };
          return event.choices?.[0]?.delta?.content;
        },
        onToken,
        signal,
      );
    },
  };
}

type ChromeSession = {
  promptStreaming(input: string, options?: { signal?: AbortSignal }): AsyncIterable<string>;
  destroy?(): void;
};

type ChromeLanguageModel = {
  availability(options?: unknown): Promise<string>;
  create(options?: unknown): Promise<ChromeSession>;
};

declare global {
  interface Window {
    LanguageModel?: ChromeLanguageModel;
  }
}

export function chromeRuntime(): RuntimeAdapter {
  return {
    id: "chrome-ai",
    label: "Chrome built-in AI",
    modelName: "Built-in foundation model",
    capabilities: { text: true, vision: false, embeddings: false, tools: false, audio: false },
    async test() {
      const lm = window.LanguageModel;
      if (!lm) throw new Error("Chrome Prompt API is unavailable.");
      const availability = await lm.availability({
        expectedInputs: [{ type: "text", languages: ["en"] }],
        expectedOutputs: [{ type: "text", languages: ["en"] }],
      });
      if (availability === "unavailable" || availability === "no") {
        throw new Error("Chrome built-in AI is unavailable on this device.");
      }
      return [String(availability)];
    },
    async generate({ messages, signal, onToken }) {
      const lm = window.LanguageModel;
      if (!lm) throw new Error("Chrome Prompt API is unavailable.");
      const system = messages.filter((message) => message.role === "system").map((item) => item.content).join("\n\n");
      const conversation = messages.filter((message) => message.role !== "system");
      const session = await lm.create({
        signal,
        initialPrompts: [
          ...(system ? [{ role: "system", content: system }] : []),
          ...conversation.slice(0, -1).map((message) => ({ role: message.role, content: message.content })),
        ],
      });
      try {
        const latest = conversation.at(-1)?.content ?? "";
        const stream = session.promptStreaming(latest, { signal });
        for await (const chunk of stream) {
          if (signal.aborted) throw new DOMException("Generation stopped", "AbortError");
          onToken(chunk);
        }
      } finally {
        session.destroy?.();
      }
    },
  };
}

const wllamaInstances = new Map<string, any>();

async function loadWllama(model: BrowserModel) {
  if (!model.opfsPath) throw new Error("This browser model has no installed file.");
  if (wllamaInstances.has(model.id)) return wllamaInstances.get(model.id);
  const [{ Wllama, LoggerWithoutDebug }, file] = await Promise.all([
    import("@wllama/wllama"),
    readOpfs(model.opfsPath),
  ]);
  const instance = new Wllama({ default: `${import.meta.env.BASE_URL}wllama/wllama.wasm` }, {
    logger: LoggerWithoutDebug,
    allowOffline: true,
  });
  await instance.loadModel([file], {
    n_ctx: model.contextLimit ?? 4096,
    n_gpu_layers: (navigator as Navigator & { gpu?: unknown }).gpu ? 99999 : 0,
  });
  wllamaInstances.set(model.id, instance);
  await db.browserModels.update(model.id, { lastUsedAt: Date.now(), status: "ready", installed: true, updatedAt: Date.now() });
  await logActivity("model", "Browser model loaded", model.name);
  return instance;
}

export function wllamaRuntime(model: BrowserModel): RuntimeAdapter {
  return {
    id: "wllama",
    label: model.name,
    modelName: model.name,
    capabilities: model.capabilities,
    async test() {
      const instance = await loadWllama(model);
      const metadata = instance.getModelMetadata?.();
      return [metadata?.meta?.["general.name"] ?? model.name];
    },
    async generate({ messages, signal, onToken, maxTokens, temperature, topP, topK }) {
      const instance = await loadWllama(model);
      const abort = () => {
        const active = wllamaInstances.get(model.id);
        if (active) {
          void active.exit().catch(() => undefined);
          wllamaInstances.delete(model.id);
        }
      };
      signal.addEventListener("abort", abort, { once: true });
      try {
        const stream = await instance.createChatCompletion({
          messages: messages.map(({ role, content }) => ({ role, content })),
          stream: true,
          max_tokens: maxTokens ?? 512,
          temperature: temperature ?? 0.7,
          top_p: topP ?? 0.9,
          top_k: topK ?? 40,
        });
        for await (const chunk of stream as AsyncIterable<any>) {
          if (signal.aborted) throw new DOMException("Generation stopped", "AbortError");
          const token = chunk?.choices?.[0]?.delta?.content;
          if (token) onToken(token);
        }
      } catch (error) {
        if (signal.aborted) throw new DOMException("Generation stopped", "AbortError");
        await logError("wllama-generation", error, model.name);
        throw error;
      } finally {
        signal.removeEventListener("abort", abort);
      }
    },
    async unload() {
      const instance = wllamaInstances.get(model.id);
      if (instance) await instance.exit();
      wllamaInstances.delete(model.id);
    },
  };
}

export async function runtimeFromChatSelection(providerId?: string, browserModelId?: string): Promise<RuntimeAdapter> {
  if (browserModelId === "chrome-ai") return chromeRuntime();
  if (browserModelId) {
    const model = await db.browserModels.get(browserModelId);
    if (!model) throw new Error("Selected browser model no longer exists.");
    return wllamaRuntime(model);
  }
  if (providerId) {
    const provider = await db.providers.get(providerId);
    if (!provider) throw new Error("Selected provider no longer exists.");
    return providerRuntime(provider);
  }
  throw new Error("Choose a browser model or provider before sending.");
}

export async function unloadAllBrowserModels() {
  for (const instance of wllamaInstances.values()) {
    await instance.exit().catch(() => undefined);
  }
  wllamaInstances.clear();
}
