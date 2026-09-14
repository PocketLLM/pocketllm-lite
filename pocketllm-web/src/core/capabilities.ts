import type { CapabilityReport } from "./types";

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
    crossOriginIsolated: window.crossOriginIsolated,
    sharedArrayBuffer: typeof SharedArrayBuffer !== "undefined",
    hardwareConcurrency: navigator.hardwareConcurrency || 1,
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
