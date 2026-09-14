import { ArrowLeft, ExternalLink, Gauge, HardDrive, Play, Power, Trash2 } from "lucide-react";
import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { humanBytes } from "../../core/capabilities";
import { useLiveValue } from "../../core/live";
import { removeBrowserModel } from "../../core/models";
import { chromeRuntime, wllamaRuntime } from "../../core/runtime";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";

export function ModelDetailPage() {
  const { modelId = "" } = useParams();
  const model = useLiveValue(() => db.browserModels.get(modelId), undefined, [modelId]);
  const downloads = useLiveValue(() => db.downloads.where("modelId").equals(modelId).reverse().sortBy("updatedAt"), [], [modelId]);
  const toast = useToast();
  const navigate = useNavigate();
  const [busy, setBusy] = useState<"load" | "unload" | "test" | null>(null);
  const [result, setResult] = useState("");

  if (!model) {
    return <section className="page"><div className="empty-state"><h2>Model not found</h2><Link to="/models">Back to Models</Link></div></section>;
  }

  const runtime = () => model.runtime === "chrome-ai" ? chromeRuntime() : wllamaRuntime(model);
  const sourceUrl = model.hfRepo ? `https://huggingface.co/${model.hfRepo}` : model.sourceUrl;

  async function run(kind: "load" | "test") {
    setBusy(kind);
    setResult("");
    try {
      const details = await runtime().test();
      setResult(`Ready · ${details.join(", ")}`);
      toast.push(kind === "load" ? "Model loaded" : "Runtime test passed", "success");
    } catch (error) {
      const message = error instanceof Error ? error.message : "Runtime failed";
      setResult(message);
      toast.push(message, "error");
    } finally {
      setBusy(null);
    }
  }

  async function unload() {
    setBusy("unload");
    try {
      await runtime().unload?.();
      toast.push("Model unloaded from memory", "success");
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Unload failed", "error");
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <div>
          <Link className="back-link" to="/models"><ArrowLeft size={15} /> Models</Link>
          <p className="eyebrow">Browser runtime</p>
          <h1>{model.name}</h1>
          <p>{model.runtime} · {model.status} · {model.installed ? "installed" : "manifest only"}</p>
        </div>
        <div className="header-tools">
          {model.installed && <button className="primary-button" disabled={busy !== null} onClick={() => void run("load")}><Play size={15} /> {busy === "load" ? "Loading…" : "Load"}</button>}
          {model.installed && model.runtime !== "chrome-ai" && <button className="soft-button" disabled={busy !== null} onClick={() => void unload()}><Power size={15} /> Unload</button>}
          <button className="soft-button" disabled={busy !== null || !model.installed} onClick={() => void run("test")}>{busy === "test" ? "Testing…" : "Test"}</button>
          <Link className="soft-button" to={`/lab/benchmark?model=${encodeURIComponent(model.id)}`}><Gauge size={15} /> Benchmark</Link>
        </div>
      </header>

      {result && <div className={result.startsWith("Ready") ? "connection-result model-detail-result" : "inline-error model-detail-result"}>{result}</div>}

      <div className="model-detail-grid">
        <Detail label="Runtime" value={model.runtime} />
        <Detail label="State" value={model.status} />
        <Detail label="Size" value={model.size ? humanBytes(model.size) : model.runtime === "chrome-ai" ? "Managed by browser" : "Unknown"} />
        <Detail label="Last loaded" value={model.lastUsedAt ? new Date(model.lastUsedAt).toLocaleString() : "Never"} />
        <Detail label="Context" value={model.contextLimit ? model.contextLimit.toLocaleString() + " tokens" : "Unknown"} />
        <Detail label="Quantization" value={model.quantization ?? "Unknown"} />
        <Detail label="Parameters" value={model.parameterClass ?? "Unknown"} />
        <Detail label="License" value={model.license ?? "Unknown"} />
      </div>

      <section className="settings-card model-detail-card">
        <div className="settings-title"><HardDrive size={18} /><div><h2>Capabilities</h2><p>Only explicit metadata is shown. Unknown remains unknown.</p></div></div>
        <div className="capability-badges">
          {Object.entries(model.capabilities).map(([key, enabled]) => <span key={key} className={enabled ? "enabled" : ""}>{key}: {enabled ? "yes" : "no"}</span>)}
        </div>
      </section>

      <section className="settings-card model-detail-card">
        <div className="settings-title"><HardDrive size={18} /><div><h2>Source & verification</h2><p>Installed model bytes are browser-private.</p></div></div>
        <dl className="model-detail-list">
          <div><dt>Source</dt><dd>{model.source}</dd></div>
          {model.hfRepo && <div><dt>Repository</dt><dd>{model.hfRepo}</dd></div>}
          {model.hfFile && <div><dt>File</dt><dd>{model.hfFile}</dd></div>}
          <div><dt>SHA-256</dt><dd className="mono">{model.sha256 ?? "Unknown"}</dd></div>
          <div><dt>OPFS path</dt><dd className="mono">{model.opfsPath ?? "Not installed"}</dd></div>
        </dl>
        {sourceUrl?.startsWith("https://") && <a className="setting-link" href={sourceUrl} target="_blank" rel="noreferrer">View upstream source <ExternalLink size={14} /></a>}
      </section>

      {downloads.length > 0 && (
        <section className="settings-card model-detail-card">
          <div className="settings-title"><HardDrive size={18} /><div><h2>Download history</h2><p>Persistent transfer state for resume and verification.</p></div></div>
          <div className="model-download-history">
            {downloads.map((task) => <div key={task.id}><strong>{task.fileName}</strong><span>{task.state} · {humanBytes(task.downloadedBytes)}{task.expectedBytes ? ` / ${humanBytes(task.expectedBytes)}` : ""}</span>{task.error && <small className="danger-text">{task.error}</small>}</div>)}
          </div>
        </section>
      )}

      <div className="danger-zone">
        <div><span className="eyebrow">Local model data</span><h2>Delete model bytes</h2><p>Hugging Face models keep a lightweight source manifest so they can be downloaded again. Manually imported models have no re-download source and are removed entirely.</p></div>
        <button className="danger-button" disabled={model.runtime === "chrome-ai"} onClick={async () => {
          if (!confirm(`Delete ${model.name} from this browser?`)) return;
          await removeBrowserModel(model.id);
          toast.push(model.source === "huggingface" ? "Model bytes removed; source manifest retained" : "Model removed", "success");
          if (model.source !== "huggingface") navigate("/models");
        }}><Trash2 size={15} /> Delete</button>
      </div>
    </section>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return <div><span>{label}</span><strong>{value}</strong></div>;
}
