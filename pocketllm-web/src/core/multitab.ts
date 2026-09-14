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


const runtimeLeases = new Map<string, { release: () => void }>();

export async function claimModelRuntimeLease(modelId: string) {
  const name = `pocketllm:model-runtime:${modelId}`;
  if (runtimeLeases.has(name)) return true;
  if (!navigator.locks?.request) return true;

  let resolveAcquired: (value: boolean) => void = () => undefined;
  const acquired = new Promise<boolean>((resolve) => { resolveAcquired = resolve; });
  let releaseLease: () => void = () => undefined;
  const released = new Promise<void>((resolve) => { releaseLease = resolve; });

  void navigator.locks.request(name, { mode: "exclusive", ifAvailable: true }, async (lock) => {
    if (!lock) {
      resolveAcquired(false);
      return;
    }
    runtimeLeases.set(name, { release: releaseLease });
    resolveAcquired(true);
    await released;
    runtimeLeases.delete(name);
  });

  return acquired;
}

export function releaseModelRuntimeLease(modelId: string) {
  const name = `pocketllm:model-runtime:${modelId}`;
  runtimeLeases.get(name)?.release();
}
