import { db, logActivity, logError } from "../db/db";
import { networkFetch } from "./network";
import { readOpfs } from "./storage";
import { claimModelRuntimeLease, releaseModelRuntimeLease, withModelLock } from "./multitab";
import { discoverRuntimeOwner, generateThroughRuntimeOwner, registerRuntimeOwner, type RemoteGenerationPayload } from "./runtimeCoordinator";
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
        const base = normalizeBaseUrl(provider.baseUrl);
        const endpoint = `${base}/api/tags`;
        const parsed = new URL(base);
        const isLoopback = ["localhost", "127.0.0.1", "::1", "[::1]"].includes(parsed.hostname);
        if (location.protocol === "https:" && parsed.protocol === "http:" && !isLoopback) {
          throw new Error("This HTTPS page may be blocked from calling an insecure HTTP LAN endpoint. Use HTTPS for Ollama, a loopback endpoint, or a browser/setup that explicitly permits local-network access.");
        }
        try {
          const response = await networkFetch(endpoint, {}, "provider-test");
          if (response.status === 401 || response.status === 403) {
            throw new Error("Ollama is reachable but rejected this web origin. Add the PocketLLM site origin to OLLAMA_ORIGINS, restart Ollama, then test again.");
          }
          if (response.status === 404) {
            throw new Error("The host is reachable, but it does not expose Ollama /api/tags. Check the base URL and port.");
          }
          if (!response.ok) throw new Error(`Ollama is reachable but returned HTTP ${response.status}.`);
          const data = (await response.json()) as { models?: Array<{ name?: string }> };
          return (data.models ?? []).flatMap((item) => item.name ? [item.name] : []);
        } catch (error) {
          if (error instanceof Error && /Strict Offline|rejected this web origin|does not expose Ollama|reachable but returned/.test(error.message)) throw error;
          if (isLoopback) {
            throw new Error("PocketLLM could not reach Ollama on this computer. Start Ollama, confirm it is listening on the configured port, then test again.");
          }
          throw new Error("PocketLLM could not reach this LAN Ollama endpoint. Check the host, Ollama listen address, browser local-network permission, firewall, and OLLAMA_ORIGINS.");
        }
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
              messages: messages.map((message) => ({
                role: message.role,
                content: message.content,
                ...(message.images?.length
                  ? { images: message.images.map((image) => image.replace(/^data:image\/[^;]+;base64,/, "")) }
                  : {}),
              })),
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
            messages: messages.map((message) => message.images?.length
              ? {
                  role: message.role,
                  content: [
                    { type: "text", text: message.content },
                    ...message.images.map((url) => ({ type: "image_url", image_url: { url } })),
                  ],
                }
              : { role: message.role, content: message.content }),
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
      const lm = (window as any).LanguageModel;
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
      const lm = (window as any).LanguageModel;
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
const wllamaOwnerDisposers = new Map<string, () => void>();

async function unloadWllamaModel(modelId: string) {
  const instance = wllamaInstances.get(modelId);
  if (instance) await instance.exit().catch(() => undefined);
  wllamaInstances.delete(modelId);
  wllamaOwnerDisposers.get(modelId)?.();
  wllamaOwnerDisposers.delete(modelId);
  releaseModelRuntimeLease(modelId);
}

async function localWllamaGenerate(
  instance: any,
  model: BrowserModel,
  request: {
    messages: RuntimeMessage[];
    signal: AbortSignal;
    onToken: (token: string) => void;
    maxTokens?: number;
    temperature?: number;
    topP?: number;
    topK?: number;
  },
) {
  const abort = () => {
    void unloadWllamaModel(model.id);
  };
  request.signal.addEventListener("abort", abort, { once: true });
  try {
    await withModelLock(model.id, async () => {
      if (request.signal.aborted) throw new DOMException("Generation stopped", "AbortError");
      const stream = await instance.createChatCompletion({
        messages: request.messages.map(({ role, content, images }) => ({
          role,
          content: images?.length
            ? [
                { type: "text", text: content },
                ...images.map((url) => ({ type: "image_url", image_url: { url } })),
              ]
            : content,
        })) as any,
        stream: true,
        max_tokens: request.maxTokens ?? 512,
        temperature: request.temperature ?? 0.7,
        top_p: request.topP ?? 0.9,
        top_k: request.topK ?? 40,
      });
      for await (const chunk of stream as AsyncIterable<any>) {
        if (request.signal.aborted) throw new DOMException("Generation stopped", "AbortError");
        const token = chunk?.choices?.[0]?.delta?.content;
        if (token) request.onToken(token);
      }
    });
  } catch (error) {
    if (request.signal.aborted) throw new DOMException("Generation stopped", "AbortError");
    await logError("wllama-generation", error, model.name);
    throw error;
  } finally {
    request.signal.removeEventListener("abort", abort);
  }
}

async function loadWllama(model: BrowserModel) {
  if (!model.opfsPath) throw new Error("This browser model has no installed file.");
  if (wllamaInstances.has(model.id)) return wllamaInstances.get(model.id);
  try {
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
    const unregister = registerRuntimeOwner(model.id, async (payload, signal, onToken) => {
      await localWllamaGenerate(instance, model, {
        messages: payload.messages,
        signal,
        onToken,
        maxTokens: payload.maxTokens,
        temperature: payload.temperature,
        topP: payload.topP,
        topK: payload.topK,
      });
    });
    wllamaOwnerDisposers.set(model.id, unregister);
    await db.browserModels.update(model.id, { lastUsedAt: Date.now(), status: "ready", installed: true, updatedAt: Date.now() });
    await logActivity("model", "Browser model loaded", model.name);
    return instance;
  } catch (error) {
    releaseModelRuntimeLease(model.id);
    throw error;
  }
}

async function remoteOrClaimedOwner(model: BrowserModel) {
  if (wllamaInstances.has(model.id)) return { local: true as const, owner: undefined };
  const owner = await discoverRuntimeOwner(model.id);
  if (owner) return { local: false as const, owner };
  const claimed = await claimModelRuntimeLease(model.id);
  if (claimed) return { local: true as const, owner: undefined };
  const lateOwner = await discoverRuntimeOwner(model.id, 500);
  if (lateOwner) return { local: false as const, owner: lateOwner };
  throw new Error("This browser model is already owned by another tab, but that tab did not answer the runtime handshake. Close the other PocketLLM tab or unload the model there, then retry.");
}

export function wllamaRuntime(model: BrowserModel): RuntimeAdapter {
  return {
    id: "wllama",
    label: model.name,
    modelName: model.name,
    capabilities: model.capabilities,
    async test() {
      const ownership = await remoteOrClaimedOwner(model);
      if (!ownership.local) return [`Ready in another PocketLLM tab · ${model.name}`];
      const instance = await loadWllama(model);
      const metadata = instance.getModelMetadata?.();
      return [metadata?.meta?.["general.name"] ?? model.name];
    },
    async generate({ messages, signal, onToken, maxTokens, temperature, topP, topK }) {
      const ownership = await remoteOrClaimedOwner(model);
      if (!ownership.local && ownership.owner) {
        const payload: RemoteGenerationPayload = { messages, maxTokens, temperature, topP, topK };
        await generateThroughRuntimeOwner(ownership.owner, model.id, payload, signal, onToken);
        return;
      }
      const instance = await loadWllama(model);
      await localWllamaGenerate(instance, model, { messages, signal, onToken, maxTokens, temperature, topP, topK });
    },
    async unload() {
      await unloadWllamaModel(model.id);
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
  for (const modelId of [...wllamaInstances.keys()]) {
    await unloadWllamaModel(modelId);
  }
}
