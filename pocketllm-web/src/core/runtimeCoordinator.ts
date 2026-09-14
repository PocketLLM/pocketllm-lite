import { tabId } from "./multitab";

export interface RemoteGenerationPayload {
  messages: Array<{ role: "system" | "user" | "assistant"; content: string; images?: string[] }>;
  maxTokens?: number;
  temperature?: number;
  topP?: number;
  topK?: number;
}

type OwnerHandler = (
  payload: RemoteGenerationPayload,
  signal: AbortSignal,
  onToken: (token: string) => void,
) => Promise<void>;

type WireMessage =
  | { kind: "who-owns"; modelId: string; from: string; nonce: string }
  | { kind: "owner"; modelId: string; from: string; to: string; nonce: string }
  | { kind: "generate"; modelId: string; from: string; to: string; requestId: string; payload: RemoteGenerationPayload }
  | { kind: "token"; from: string; to: string; requestId: string; token: string }
  | { kind: "done"; from: string; to: string; requestId: string }
  | { kind: "error"; from: string; to: string; requestId: string; error: string }
  | { kind: "abort"; from: string; to: string; requestId: string };

const channel = "BroadcastChannel" in window ? new BroadcastChannel("pocketllm-model-runtime") : null;
const handlers = new Map<string, OwnerHandler>();
const inbound = new Map<string, AbortController>();
const pending = new Map<string, {
  resolve: () => void;
  reject: (error: Error) => void;
  onToken: (token: string) => void;
}>();
const discoveries = new Map<string, (owner?: string) => void>();

channel?.addEventListener("message", (event: MessageEvent<WireMessage>) => {
  const message = event.data;
  if (!message || message.from === tabId) return;

  if (message.kind === "who-owns") {
    if (handlers.has(message.modelId)) {
      channel.postMessage({
        kind: "owner",
        modelId: message.modelId,
        from: tabId,
        to: message.from,
        nonce: message.nonce,
      } satisfies WireMessage);
    }
    return;
  }

  if (message.kind === "owner") {
    if (message.to !== tabId) return;
    discoveries.get(message.nonce)?.(message.from);
    return;
  }

  if (message.kind === "generate") {
    if (message.to !== tabId) return;
    const handler = handlers.get(message.modelId);
    if (!handler) return;
    const controller = new AbortController();
    inbound.set(message.requestId, controller);
    void handler(message.payload, controller.signal, (token) => {
      channel.postMessage({ kind: "token", from: tabId, to: message.from, requestId: message.requestId, token } satisfies WireMessage);
    }).then(() => {
      channel.postMessage({ kind: "done", from: tabId, to: message.from, requestId: message.requestId } satisfies WireMessage);
    }).catch((error) => {
      channel.postMessage({
        kind: "error",
        from: tabId,
        to: message.from,
        requestId: message.requestId,
        error: error instanceof Error ? error.message : String(error),
      } satisfies WireMessage);
    }).finally(() => inbound.delete(message.requestId));
    return;
  }

  if (message.kind === "abort") {
    if (message.to === tabId) inbound.get(message.requestId)?.abort();
    return;
  }

  if (message.to !== tabId) return;
  const request = pending.get(message.requestId);
  if (!request) return;
  if (message.kind === "token") request.onToken(message.token);
  if (message.kind === "done") {
    pending.delete(message.requestId);
    request.resolve();
  }
  if (message.kind === "error") {
    pending.delete(message.requestId);
    request.reject(new Error(message.error));
  }
});

export function registerRuntimeOwner(modelId: string, handler: OwnerHandler) {
  handlers.set(modelId, handler);
  return () => handlers.delete(modelId);
}

export async function discoverRuntimeOwner(modelId: string, timeoutMs = 180) {
  if (!channel) return undefined;
  const nonce = crypto.randomUUID();
  return new Promise<string | undefined>((resolve) => {
    let settled = false;
    const finish = (owner?: string) => {
      if (settled) return;
      settled = true;
      discoveries.delete(nonce);
      window.clearTimeout(timer);
      resolve(owner);
    };
    discoveries.set(nonce, finish);
    const timer = window.setTimeout(() => finish(undefined), timeoutMs);
    channel.postMessage({ kind: "who-owns", modelId, from: tabId, nonce } satisfies WireMessage);
  });
}

export async function generateThroughRuntimeOwner(
  ownerTabId: string,
  modelId: string,
  payload: RemoteGenerationPayload,
  signal: AbortSignal,
  onToken: (token: string) => void,
) {
  if (!channel) throw new Error("Cross-tab runtime coordination is unavailable.");
  const requestId = crypto.randomUUID();
  const promise = new Promise<void>((resolve, reject) => {
    pending.set(requestId, { resolve, reject, onToken });
  });
  const abort = () => {
    channel.postMessage({ kind: "abort", from: tabId, to: ownerTabId, requestId } satisfies WireMessage);
    const request = pending.get(requestId);
    pending.delete(requestId);
    request?.reject(new DOMException("Generation stopped", "AbortError"));
  };
  signal.addEventListener("abort", abort, { once: true });
  channel.postMessage({
    kind: "generate",
    modelId,
    from: tabId,
    to: ownerTabId,
    requestId,
    payload,
  } satisfies WireMessage);
  try {
    await promise;
  } finally {
    signal.removeEventListener("abort", abort);
    pending.delete(requestId);
  }
}
