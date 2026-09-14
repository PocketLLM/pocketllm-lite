import { Check, ChevronRight, Cpu, HardDrive, Laptop, Server, ShieldCheck, Sparkles, X } from "lucide-react";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import { probeCapabilities, humanBytes } from "../core/capabilities";
import { requestPersistentStorage } from "../core/storage";
import { useLiveValue } from "../core/live";
import type { CapabilityReport } from "../core/types";
import { db, saveSetting } from "../db/db";
import { useRegisterSW } from "virtual:pwa-register/react";

export function BootExperience({ children }: { children: ReactNode }) {
  const onboarding = useLiveValue(() => db.settings.get("onboardingComplete"), undefined, []);
  const appearance = useLiveValue(() => db.settings.get("appearance"), undefined, []);
  const fontScale = useLiveValue(() => db.settings.get("fontScale"), undefined, []);

  useEffect(() => {
    const mode = String(appearance?.value ?? "system");
    document.documentElement.dataset.theme = mode;
    document.documentElement.style.fontSize = `${Number(fontScale?.value ?? 100)}%`;
  }, [appearance?.value, fontScale?.value]);

  return (
    <>
      {children}
      {onboarding && onboarding.value !== true && <SetupWizard />}
      <UpdateBanner />
    </>
  );
}

function SetupWizard() {
  const [step, setStep] = useState(0);
  const [report, setReport] = useState<CapabilityReport | null>(null);
  const [probing, setProbing] = useState(false);

  async function probe() {
    setProbing(true);
    try {
      const next = await probeCapabilities();
      setReport(next);
      setStep(1);
    } finally {
      setProbing(false);
    }
  }

  async function finish() {
    await requestPersistentStorage().catch(() => false);
    await saveSetting("onboardingComplete", true);
  }

  const recommendation = useMemo(() => {
    if (!report) return "";
    if (report.webgpu && report.hardwareConcurrency >= 8) return "Browser GGUF and Ollama should both be comfortable choices on this device.";
    if (report.webgpu) return "Start with a small browser model or Ollama. Larger browser models may hit memory pressure.";
    return "Use a tiny browser model through WASM, Chrome built-in AI when available, or Ollama for the best experience.";
  }, [report]);

  return (
    <div className="onboarding-layer" role="dialog" aria-modal="true" aria-labelledby="setup-title">
      <div className="onboarding-card">
        {step === 0 ? (
          <>
            <div className="setup-symbol"><Sparkles size={24} /></div>
            <span className="eyebrow">PocketLLM Web</span>
            <h1 id="setup-title">Your AI workspace,<br />living on your device.</h1>
            <p>No account. No mandatory cloud. Chats and app state stay in this browser unless you explicitly connect an external runtime.</p>
            <div className="setup-choice-grid">
              <div><Laptop size={19} /><strong>Browser model</strong><span>GGUF with WebGPU/WASM</span></div>
              <div><Server size={19} /><strong>Ollama</strong><span>Same device or your LAN</span></div>
              <div><Cpu size={19} /><strong>Built-in AI</strong><span>When Chrome exposes it</span></div>
              <div><ShieldCheck size={19} /><strong>Explicit provider</strong><span>Endpoint you choose</span></div>
            </div>
            <div className="setup-actions">
              <button className="text-action" onClick={() => void finish()}>Skip setup</button>
              <button className="primary-button" disabled={probing} onClick={() => void probe()}>{probing ? "Checking…" : "Check this device"} <ChevronRight size={16} /></button>
            </div>
          </>
        ) : (
          <>
            <div className="setup-symbol"><HardDrive size={24} /></div>
            <span className="eyebrow">Capability check</span>
            <h1 id="setup-title">This browser is ready.</h1>
            <p>{recommendation}</p>
            <div className="capability-list">
              <Capability label="WebGPU" value={report?.webgpu ? "Available" : "Unavailable"} good={Boolean(report?.webgpu)} />
              <Capability label="WebAssembly" value={report?.wasm ? "Available" : "Unavailable"} good={Boolean(report?.wasm)} />
              <Capability label="Cross-origin isolation" value={report?.crossOriginIsolated ? "Active" : "Missing"} good={Boolean(report?.crossOriginIsolated)} />
              <Capability label="Chrome built-in AI" value={report?.chromeAI ?? "unknown"} good={report?.chromeAI === "available"} />
              <Capability label="Storage quota" value={report?.storageQuota ? humanBytes(report.storageQuota) : "Browser did not expose it"} good={true} />
              <Capability label="CPU threads exposed" value={String(report?.hardwareConcurrency ?? 1)} good={(report?.hardwareConcurrency ?? 1) >= 4} />
            </div>
            <div className="setup-note">PocketLLM only checks capabilities needed for local runtimes. It does not build a fingerprint profile.</div>
            <div className="setup-actions">
              <button className="soft-button" onClick={() => setStep(0)}>Back</button>
              <button className="primary-button" onClick={() => void finish()}>Enter PocketLLM <ChevronRight size={16} /></button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function Capability({ label, value, good }: { label: string; value: string; good: boolean }) {
  return <div><span>{label}</span><strong>{value}</strong>{good ? <Check size={15} /> : <X size={15} />}</div>;
}

function UpdateBanner() {
  const {
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    onRegisteredSW(_url, registration) {
      if (registration) window.setInterval(() => void registration.update(), 60 * 60 * 1000);
    },
  });

  if (!needRefresh) return null;
  return (
    <div className="update-banner" role="status">
      <div><strong>New PocketLLM version ready</strong><span>Your current work will stay local.</span></div>
      <button className="soft-button" onClick={() => setNeedRefresh(false)}>Later</button>
      <button className="primary-button small" onClick={() => void updateServiceWorker(true)}>Update now</button>
    </div>
  );
}
