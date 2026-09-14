import { Bot, CheckCircle2, Chrome, Cpu, Download, FileUp, HardDriveDownload, Search, Trash2, XCircle } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { useLiveValue } from "../../core/live";
import { humanBytes, probeCapabilities } from "../../core/capabilities";
import {
  addBrowserModelFromFile,
  downloadTask,
  ensureChromeModelRecord,
  installHuggingFaceModel,
  listHuggingFaceGguf,
  removeBrowserModel,
  searchHuggingFace,
  type HuggingFaceFile,
  type HuggingFaceResult,
} from "../../core/models";
import { wllamaRuntime, chromeRuntime } from "../../core/runtime";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";
import { Modal } from "../../components/Modal";

export function ModelsPage() {
  const models = useLiveValue(() => db.browserModels.orderBy("updatedAt").reverse().toArray(), [], []);
  const downloads = useLiveValue(() => db.downloads.orderBy("updatedAt").reverse().toArray(), [], []);
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState("Qwen GGUF");
  const [results, setResults] = useState<HuggingFaceResult[]>([]);
  const [selected, setSelected] = useState<HuggingFaceResult | null>(null);
  const [files, setFiles] = useState<HuggingFaceFile[]>([]);
  const [searching, setSearching] = useState(false);
  const [testing, setTesting] = useState<string>();
  const [testResult, setTestResult] = useState<Record<string, string>>({});

  const activeDownloads = useMemo(() => downloads.filter((task) => ["queued", "downloading", "verifying", "installing"].includes(task.state)), [downloads]);

  async function search() {
    setSearching(true);
    try {
      setResults(await searchHuggingFace(query));
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Hugging Face search failed", "error");
    } finally {
      setSearching(false);
    }
  }

  async function openRepo(result: HuggingFaceResult) {
    setSelected(result);
    setFiles([]);
    try {
      setFiles(await listHuggingFaceGguf(result.id));
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Could not load GGUF files", "error");
    }
  }

  async function testModel(id: string) {
    const model = await db.browserModels.get(id);
    if (!model) return;
    setTesting(id);
    try {
      const runtime = model.runtime === "chrome-ai" ? chromeRuntime() : wllamaRuntime(model);
      const details = await runtime.test();
      setTestResult((old) => ({ ...old, [id]: `Ready · ${details.join(", ")}` }));
    } catch (error) {
      setTestResult((old) => ({ ...old, [id]: error instanceof Error ? error.message : "Runtime test failed" }));
    } finally {
      setTesting(undefined);
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Local inference</p><h1>Models</h1><p>Import GGUF, install a verified file from Hugging Face, or use Chrome's built-in model when your browser exposes it.</p></div>
        <div className="header-tools">
          <button className="soft-button" onClick={async () => {
            const report = await probeCapabilities();
            if (report.chromeAI === "unavailable") return toast.push("Chrome built-in AI is unavailable on this device.", "error");
            await ensureChromeModelRecord();
            toast.push("Chrome built-in AI added", "success");
          }}><Chrome size={16} /> Chrome AI</button>
          <button className="primary-button" onClick={() => fileRef.current?.click()}><FileUp size={16} /> Import GGUF</button>
          <input ref={fileRef} hidden type="file" accept=".gguf" onChange={async (event) => {
            const file = event.target.files?.[0];
            if (!file) return;
            try {
              await addBrowserModelFromFile(file);
              toast.push("GGUF imported", "success");
            } catch (error) {
              toast.push(error instanceof Error ? error.message : "Import failed", "error");
            } finally {
              event.target.value = "";
            }
          }} />
        </div>
      </header>

      {activeDownloads.length > 0 && (
        <div className="download-stack">
          {activeDownloads.map((task) => (
            <div className="download-row" key={task.id}>
              <HardDriveDownload size={17} />
              <div>
                <strong>{task.fileName}</strong>
                <span>{task.state} · {humanBytes(task.downloadedBytes)}{task.expectedBytes ? ` / ${humanBytes(task.expectedBytes)}` : ""}</span>
                <progress max={task.expectedBytes ?? 1} value={task.downloadedBytes} />
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="section-heading"><h2>Installed & available</h2></div>
      <div className="model-grid">
        {models.length === 0 ? <div className="empty-state wide"><Cpu size={28} /><h2>No browser models yet</h2><p>Import a small GGUF or connect Ollama from Providers.</p></div> :
          models.map((model) => (
            <article className="provider-card" key={model.id}>
              <div className="provider-heading"><div className="model-icon">{model.runtime === "chrome-ai" ? <Chrome size={20} /> : <Bot size={20} />}</div><div><strong>{model.name}</strong><span>{model.runtime} · {model.status}</span></div></div>
              <dl>
                <div><dt>Size</dt><dd>{model.size ? humanBytes(model.size) : "Managed by browser"}</dd></div>
                <div><dt>License</dt><dd>{model.license ?? "Unknown"}</dd></div>
                <div><dt>Capabilities</dt><dd>{Object.entries(model.capabilities).filter(([, value]) => value).map(([key]) => key).join(", ") || "Unknown"}</dd></div>
              </dl>
              {testResult[model.id] && <p className={testResult[model.id].startsWith("Ready") ? "connection-result" : "inline-error"}>{testResult[model.id].startsWith("Ready") ? <CheckCircle2 size={15} /> : <XCircle size={15} />} {testResult[model.id]}</p>}
              <div className="card-actions">
                <button className="soft-button" disabled={testing === model.id} onClick={() => void testModel(model.id)}>{testing === model.id ? "Testing…" : "Test"}</button>
                {model.runtime !== "chrome-ai" && <button className="icon-button danger" onClick={async () => {
                  if (window.confirm(`Delete ${model.name} from this browser?`)) await removeBrowserModel(model.id);
                }} aria-label={`Delete ${model.name}`}><Trash2 size={16} /></button>}
              </div>
            </article>
          ))}
      </div>

      <div className="section-heading hf-heading">
        <div><h2>Hugging Face GGUF browser</h2><p>Only files with GGUF metadata get an install action. File hashes are verified when the Hub exposes SHA-256 metadata.</p></div>
        <div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") void search(); }} /><button className="text-action" onClick={() => void search()}>{searching ? "Searching…" : "Search"}</button></div>
      </div>

      <div className="hf-results">
        {results.map((result) => (
          <button className="hf-result" key={result.id} onClick={() => void openRepo(result)}>
            <strong>{result.id}</strong>
            <span>{result.downloads.toLocaleString()} downloads · {result.likes.toLocaleString()} likes · {result.license ?? "license unknown"}</span>
          </button>
        ))}
      </div>

      <Modal open={Boolean(selected)} title={selected?.id ?? "GGUF files"} onClose={() => setSelected(null)} width="780px">
        {files.length === 0 ? <div className="empty-state"><Download size={24} /><p>No GGUF files found or repository still loading.</p></div> :
          <div className="file-list">
            {files.map((file) => (
              <div className="file-row" key={file.name}>
                <div><strong>{file.name}</strong><span>{file.size ? humanBytes(file.size) : "size unknown"} · {file.sha256 ? "SHA available" : "hash unavailable"}</span></div>
                <button className="primary-button small" onClick={async () => {
                  if (!selected) return;
                  try {
                    await installHuggingFaceModel(selected.id, file, { license: selected.license, name: file.name.replace(/\.gguf$/i, "") });
                    toast.push("Model installed", "success");
                    setSelected(null);
                  } catch (error) {
                    toast.push(error instanceof Error ? error.message : "Model install failed", "error");
                  }
                }}><Download size={15} /> Install</button>
              </div>
            ))}
          </div>}
      </Modal>
    </section>
  );
}
