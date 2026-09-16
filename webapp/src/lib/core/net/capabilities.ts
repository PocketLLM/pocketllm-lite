/**
 * CapabilityProbe — browser capability diagnostics.
 *
 * Probes only what PocketLLM genuinely needs to make local runtime
 * decisions (no aggressive fingerprinting). Results power the
 * Settings → Models "Capabilities" panel and runtime recommendations.
 */

export interface Capabilities {
  webgpu: boolean;
  wasmSimd: boolean;
  crossOriginIsolated: boolean;
  sharedArrayBuffer: boolean;
  hardwareConcurrency: number;
  deviceMemoryGb: number | null;
  opfs: boolean;
  indexedDB: boolean;
  storageQuota: { usage: number; quota: number } | null;
  storagePersisted: boolean;
  chromeBuiltInAI: 'available' | 'unavailable' | 'unsupported';
  speechRecognition: 'available' | 'unavailable';
  notifications: NotificationPermission | 'unsupported';
  clipboardWrite: boolean;
  speechSynthesis: boolean;
  browser: string;
  platform: string;
  language: string;
  scannedAt: number;
}

function detectBrowser(): string {
  if (typeof navigator === 'undefined') return 'unknown';
  const ua = navigator.userAgent;
  if (ua.includes('Firefox/')) return 'Firefox';
  if (ua.includes('Edg/')) return 'Edge';
  if (ua.includes('Chrome/')) return 'Chrome';
  if (ua.includes('Safari/') && !ua.includes('Chrome')) return 'Safari';
  return 'Other';
}

/** WebAssembly SIMD detection (feature test, no fingerprinting beyond need). */
async function detectWasmSimd(): Promise<boolean> {
  try {
    return WebAssembly.validate(
      new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 0, 1, 123, 3, 2, 1, 0, 10, 10,
        1, 8, 0, 65, 0, 253, 15, 253, 98, 11,
      ])
    );
  } catch {
    return false;
  }
}

async function detectWebGPU(): Promise<boolean> {
  try {
    const gpu = (navigator as Navigator & { gpu?: { requestAdapter(): Promise<unknown> } })
      .gpu;
    if (!gpu) return false;
    const adapter = await gpu.requestAdapter();
    return adapter != null;
  } catch {
    return false;
  }
}

async function detectChromeBuiltInAI(): Promise<Capabilities['chromeBuiltInAI']> {
  try {
    const ai = (
      window as unknown as {
        ai?: { languageModel?: { availability(): Promise<string> } };
      }
    ).ai;
    if (!ai?.languageModel) return 'unsupported';
    const availability = await ai.languageModel.availability();
    return availability === 'available' ? 'available' : 'unavailable';
  } catch {
    return 'unsupported';
  }
}

export class CapabilityProbe {
  private cache: Capabilities | null = null;

  /** Runs all probes (each individually guarded) and caches the result. */
  async scan(): Promise<Capabilities> {
    if (this.cache) return this.cache;

    const [webgpu, wasmSimd, chromeBuiltInAI] = await Promise.all([
      detectWebGPU(),
      detectWasmSimd(),
      detectChromeBuiltInAI(),
    ]);

    let storageQuota: { usage: number; quota: number } | null = null;
    let storagePersisted = false;
    try {
      if (navigator.storage?.estimate) {
        const est = await navigator.storage.estimate();
        storageQuota = { usage: est.usage ?? 0, quota: est.quota ?? 0 };
      }
      if (navigator.storage?.persisted) {
        storagePersisted = await navigator.storage.persisted();
      }
    } catch {
      /* private mode / unsupported */
    }

    const capabilities: Capabilities = {
      webgpu,
      wasmSimd,
      crossOriginIsolated: typeof crossOriginIsolated !== 'undefined'
        ? crossOriginIsolated
        : false,
      sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
      hardwareConcurrency: navigator.hardwareConcurrency ?? 1,
      deviceMemoryGb: (navigator as Navigator & { deviceMemory?: number })
        .deviceMemory ?? null,
      opfs:
        typeof navigator !== 'undefined' &&
        !!navigator.storage &&
        'getDirectory' in navigator.storage,
      indexedDB: typeof indexedDB !== 'undefined',
      storageQuota,
      storagePersisted,
      chromeBuiltInAI,
      speechRecognition:
        'SpeechRecognition' in window || 'webkitSpeechRecognition' in window
          ? 'available'
          : 'unavailable',
      notifications: typeof Notification !== 'undefined'
        ? Notification.permission
        : 'unsupported',
      clipboardWrite: typeof navigator !== 'undefined' && !!navigator.clipboard,
      speechSynthesis: typeof speechSynthesis !== 'undefined',
      browser: detectBrowser(),
      platform: navigator.platform ?? 'unknown',
      language: navigator.language ?? 'en',
      scannedAt: Date.now(),
    };

    this.cache = capabilities;
    return capabilities;
  }

  /** Asks the browser for persistent storage (after meaningful data exists). */
  async requestPersistence(): Promise<boolean> {
    try {
      if (navigator.storage?.persist) {
        const granted = await navigator.storage.persist();
        if (granted && this.cache) this.cache.storagePersisted = true;
        return granted;
      }
    } catch {
      /* ignore */
    }
    return false;
  }

  invalidate(): void {
    this.cache = null;
  }
}

export const capabilityProbe = new CapabilityProbe();
