const channel = "BroadcastChannel" in window ? new BroadcastChannel("pocketllm-web") : null;

export type PocketEvent =
  | { type: "model-owner"; tabId: string; modelId: string }
  | { type: "model-released"; tabId: string; modelId: string }
  | { type: "data-changed"; table: string };

export const tabId = crypto.randomUUID();

export function broadcast(event: PocketEvent) {
  channel?.postMessage(event);
}

export function subscribe(handler: (event: PocketEvent) => void) {
  if (!channel) return () => undefined;
  const listener = (event: MessageEvent<PocketEvent>) => handler(event.data);
  channel.addEventListener("message", listener);
  return () => channel.removeEventListener("message", listener);
}

export async function withExclusiveLock<T>(name: string, operation: () => Promise<T>): Promise<T> {
  if (!navigator.locks?.request) return operation();
  return navigator.locks.request(`pocketllm:${name}`, { mode: "exclusive" }, operation);
}

export async function withModelLock<T>(modelId: string, operation: () => Promise<T>): Promise<T> {
  return withExclusiveLock(`model:${modelId}`, operation);
}
