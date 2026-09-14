import type { CapabilityReport } from "./types";

function detectWasmSimd() {
  if (typeof WebAssembly === "undefined") return false;
  try {
    return WebAssembly.validate(new Uint8Array([
      0,97,115,109,1,0,0,0,1,5,1,96,0,1,123,3,2,1,0,10,10,1,8,0,65,0,253,15,11
    ]));
  } catch {
    return false;
  }
}

function browserLabel() {
  const ua = navigator.userAgent;
  if (/Edg\//.test(ua)) return "Edge";
  if (/Firefox\//.test(ua)) return "Firefox";
  if (/Chrome\//.test(ua) && !/Edg\//.test(ua)) return "Chrome";
  if (/Safari\//.test(ua) && !/Chrome\//.test(ua)) return "Safari";
  return "Unknown browser";
}

async function localNetworkAccessState(): Promise<CapabilityReport["localNetworkAccess"]> {
  const permissions = navigator.permissions as Permissions & { query(descriptor: PermissionDescriptor & { name: string }): Promise<PermissionStatus> };
  if (!permissions?.query) return "unsupported";
  try {
    const status = await permissions.query({ name: "local-network-access" } as PermissionDescriptor & { name: string });
    return status.state === "granted" ? "granted" : status.state === "prompt" ? "prompt" : "denied";
  } catch {
    return "unsupported";
  }
}

export async function probeCapabilities(): Promise<CapabilityReport> {
  const estimate = await navigator.storage?.estimate?.();
  const persistentStorage = (await navigator.storage?.persisted?.()) ?? false;

  let chromeAI: CapabilityReport["chromeAI"] = "unknown";
  const lm = (window as any).LanguageModel;
  if (lm?.availability) {
    try {
      const value = await lm.availability({
        expectedInputs: [{ type: "text", languages: ["en"] }],
        expectedOutputs: [{ type: "text", languages: ["en"] }],
      });
      chromeAI =
        value === "available" || value === "readily"
          ? "available"
          : value === "downloading"
            ? "downloading"
            : value === "downloadable" || value === "after-download"
              ? "downloadable"
              : value === "unavailable" || value === "no"
                ? "unavailable"
                : "unknown";
    } catch {
      chromeAI = "unknown";
    }
  } else {
    chromeAI = "unavailable";
  }

  return {
    webgpu: Boolean((navigator as Navigator & { gpu?: unknown }).gpu),
    wasm: typeof WebAssembly !== "undefined",
    wasmSimd: detectWasmSimd(),
    crossOriginIsolated: window.crossOriginIsolated,
    sharedArrayBuffer: typeof SharedArrayBuffer !== "undefined",
    hardwareConcurrency: navigator.hardwareConcurrency || 1,
    browser: browserLabel(),
    platform: navigator.userAgentData?.platform ?? navigator.platform ?? "Unknown",
    localNetworkAccess: await localNetworkAccessState(),
    storageQuota: estimate?.quota,
    storageUsage: estimate?.usage,
    persistentStorage,
    chromeAI,
    microphone: Boolean(navigator.mediaDevices?.getUserMedia),
    speechRecognition: Boolean((window as any).SpeechRecognition || (window as any).webkitSpeechRecognition),
    notifications: "Notification" in window,
  };
}

export function humanBytes(bytes = 0) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** index;
  return `${value >= 10 || index === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[index]}`;
}
