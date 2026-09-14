import { db, logActivity, logError, setting } from "../db/db";
import type { BrowserModel, DownloadTask } from "./types";
import { networkFetch } from "./network";
import { appendOpfs, deleteOpfs, readOpfs, requestPersistentStorage, sha256, writeOpfs } from "./storage";
import { withModelLock } from "./multitab";
import { beginBusy } from "./busy";

type HfModel = {
  id?: string;
  modelId?: string;
  downloads?: number;
  likes?: number;
  tags?: string[];
  cardData?: { license?: string };
};

const activeDownloadControllers = new Map<string, AbortController>();
const pauseRequested = new Set<string>();

function hfHeaders() {
  const token = sessionStorage.getItem("huggingface-token");
  return token ? { Authorization: `Bearer ${token}` } : undefined;
}

type HfFile = {
  rfilename?: string;
  size?: number;
  lfs?: { oid?: string; size?: number };
};

export interface HuggingFaceResult {
  id: string;
  downloads: number;
  likes: number;
  tags: string[];
  license?: string;
}

export interface HuggingFaceFile {
  name: string;
  size?: number;
  sha256?: string;
}

export async function searchHuggingFace(query: string): Promise<HuggingFaceResult[]> {
  if (!(await setting("onlineModelBrowsing", true))) throw new Error("Online model browsing is disabled.");
  const params = new URLSearchParams({
    search: query.trim() || "GGUF",
    filter: "gguf",
    sort: "downloads",
    direction: "-1",
    limit: "25",
    full: "true",
  });
  const response = await networkFetch(`https://huggingface.co/api/models?${params}`, { headers: hfHeaders() }, "huggingface-search");
  if (!response.ok) throw new Error(`Hugging Face returned HTTP ${response.status}`);
  const rows = (await response.json()) as HfModel[];
  return rows.flatMap((row) => {
    const id = row.id ?? row.modelId;
    if (!id) return [];
    const licenseTag = row.tags?.find((tag) => tag.startsWith("license:"))?.slice(8);
    return [{
      id,
      downloads: row.downloads ?? 0,
      likes: row.likes ?? 0,
      tags: row.tags ?? [],
      license: row.cardData?.license ?? licenseTag,
    }];
  });
}

export async function listHuggingFaceGguf(repo: string): Promise<HuggingFaceFile[]> {
  const response = await networkFetch(`https://huggingface.co/api/models/${encodeURIComponent(repo)}?blobs=true`, { headers: hfHeaders() }, "huggingface-search");
  if (!response.ok) throw new Error(`Hugging Face returned HTTP ${response.status}`);
  const data = (await response.json()) as { siblings?: HfFile[] };
  return (data.siblings ?? [])
    .filter((file) => file.rfilename?.toLowerCase().endsWith(".gguf"))
    .map((file) => ({
      name: file.rfilename!,
      size: file.lfs?.size ?? file.size,
      sha256: file.lfs?.oid?.replace(/^sha256:/, ""),
    }));
}

export async function addBrowserModelFromFile(file: File) {
  if (!file.name.toLowerCase().endsWith(".gguf")) throw new Error("Choose a GGUF model file.");
  const header = new Uint8Array(await file.slice(0, 4).arrayBuffer());
  if (String.fromCharCode(...header) !== "GGUF") throw new Error("The selected file is not a valid GGUF model.");
  const hash = await sha256(file);
  const id = crypto.randomUUID();
  const path = `models/${id}/${file.name.replace(/[^a-zA-Z0-9._-]+/g, "_")}`;
  await writeOpfs(path, file);
  const now = Date.now();
  const model: BrowserModel = {
    id,
    name: file.name.replace(/\.gguf$/i, ""),
    runtime: "wllama",
    source: "file",
    opfsPath: path,
    sha256: hash,
    size: file.size,
    capabilities: { text: true, vision: false, embeddings: false, tools: false, audio: false },
    installed: true,
    status: "ready",
    createdAt: now,
    updatedAt: now,
  };
  await db.browserModels.add(model);
  void requestPersistentStorage().catch(() => false);
  await logActivity("model", "GGUF imported", file.name);
  return model;
}

async function createDownloadTask(model: BrowserModel, url: string, fileName: string, path: string, expectedBytes?: number, hash?: string) {
  const task: DownloadTask = {
    id: crypto.randomUUID(),
    modelId: model.id,
    url,
    fileName,
    opfsPath: path,
    state: "queued",
    downloadedBytes: 0,
    expectedBytes,
    sha256: hash,
    createdAt: Date.now(),
    updatedAt: Date.now(),
  };
  await db.downloads.add(task);
  return task;
}

export async function installHuggingFaceModel(
  repo: string,
  file: HuggingFaceFile,
  metadata?: { license?: string; name?: string; onProgress?: (task: DownloadTask) => void; signal?: AbortSignal },
) {
  if (file.size && file.size > 2 * 1024 * 1024 * 1024) {
    throw new Error("This single GGUF file is larger than the 2 GB browser model limit. Choose a smaller or split model.");
  }
  const estimate = await navigator.storage?.estimate?.();
  if (file.size && estimate?.quota && estimate?.usage && estimate.quota - estimate.usage < file.size * 1.08) {
    throw new Error("This browser does not currently report enough free storage for the selected model.");
  }
  const modelId = crypto.randomUUID();
  const path = `models/${modelId}/${file.name.replace(/\//g, "_")}`;
  const now = Date.now();
  const model: BrowserModel = {
    id: modelId,
    name: metadata?.name ?? file.name.replace(/\.gguf$/i, ""),
    runtime: "wllama",
    source: "huggingface",
    hfRepo: repo,
    hfFile: file.name,
    sourceUrl: `https://huggingface.co/${repo}/resolve/main/${file.name}`,
    opfsPath: path,
    sha256: file.sha256,
    size: file.size,
    license: metadata?.license,
    capabilities: { text: true, vision: false, embeddings: false, tools: false, audio: false },
    installed: false,
    status: "queued",
    createdAt: now,
    updatedAt: now,
  };
  await db.browserModels.add(model);
  const task = await createDownloadTask(model, model.sourceUrl!, file.name, path, file.size, file.sha256);
  await downloadTask(task.id, metadata?.onProgress, metadata?.signal);
  return db.browserModels.get(model.id);
}

async function downloadTaskUnlocked(
  taskId: string,
  onProgress?: (task: DownloadTask) => void,
  signal?: AbortSignal,
) {
  const task = await db.downloads.get(taskId);
  if (!task) throw new Error("Download task not found.");
  const model = await db.browserModels.get(task.modelId);
  if (!model) throw new Error("Model record not found.");

  let existing = 0;
  try {
    existing = (await readOpfs(task.opfsPath)).size;
  } catch {
    existing = 0;
  }

  const headers: Record<string, string> = { ...(hfHeaders() ?? {}) };
  if (existing > 0) headers.Range = `bytes=${existing}-`;
  if (existing > 0 && task.etag) headers["If-Range"] = task.etag;
  else if (existing > 0 && task.lastModified) headers["If-Range"] = task.lastModified;

  await db.downloads.update(task.id, { state: "downloading", downloadedBytes: existing, updatedAt: Date.now(), error: undefined });
  await db.browserModels.update(model.id, { status: "downloading", updatedAt: Date.now() });

  let response = await networkFetch(task.url, { headers, signal }, "huggingface-download");
  let offset = existing;

  if (existing > 0 && response.status === 200) {
    await deleteOpfs(task.opfsPath).catch(() => undefined);
    offset = 0;
    response = await networkFetch(task.url, { signal, headers: hfHeaders() }, "huggingface-download");
  }
  if (existing > 0 && response.status !== 206 && response.status !== 200) {
    throw new Error(`Resume failed with HTTP ${response.status}`);
  }
  if (!response.ok || !response.body) throw new Error(`Download failed with HTTP ${response.status}`);

  const contentLength = Number(response.headers.get("Content-Length") ?? "0") || undefined;
  const expectedBytes = task.expectedBytes ?? (contentLength ? offset + contentLength : undefined);
  const etag = response.headers.get("ETag") ?? task.etag;
  const lastModified = response.headers.get("Last-Modified") ?? task.lastModified;
  await db.downloads.update(task.id, { expectedBytes, etag, lastModified });

  const reader = response.body.getReader();
  try {
    while (true) {
      if (signal?.aborted) throw new DOMException("Download cancelled", "AbortError");
      const { done, value } = await reader.read();
      if (done) break;
      await appendOpfs(task.opfsPath, value, offset);
      offset += value.byteLength;
      const updated = {
        ...task,
        state: "downloading" as const,
        downloadedBytes: offset,
        expectedBytes,
        etag: etag ?? undefined,
        lastModified: lastModified ?? undefined,
        updatedAt: Date.now(),
      };
      await db.downloads.update(task.id, updated);
      onProgress?.(updated);
    }

    await db.downloads.update(task.id, { state: "verifying", downloadedBytes: offset, updatedAt: Date.now() });
    await db.browserModels.update(model.id, { status: "verifying", updatedAt: Date.now() });
    const downloaded = await readOpfs(task.opfsPath);
    const header = new Uint8Array(await downloaded.slice(0, 4).arrayBuffer());
    if (String.fromCharCode(...header) !== "GGUF") throw new Error("Downloaded file is not a valid GGUF model.");
    const digest = await sha256(downloaded);
    if (task.sha256 && digest.toLowerCase() !== task.sha256.toLowerCase()) {
      throw new Error("SHA-256 verification failed. The downloaded model was not installed.");
    }
    await db.downloads.update(task.id, { state: "ready", downloadedBytes: offset, updatedAt: Date.now() });
    await db.browserModels.update(model.id, { status: "ready", installed: true, size: downloaded.size, sha256: digest, updatedAt: Date.now() });
    void requestPersistentStorage().catch(() => false);
    await logActivity("model", "Model installed", model.name);
  } catch (error) {
    const cancelled = error instanceof DOMException && error.name === "AbortError";
    const paused = cancelled && pauseRequested.has(task.id);
    if (paused) pauseRequested.delete(task.id);
    await db.downloads.update(task.id, { state: paused ? "paused" : cancelled ? "cancelled" : "failed", error: cancelled ? undefined : error instanceof Error ? error.message : String(error), updatedAt: Date.now() });
    await db.browserModels.update(model.id, { status: paused ? "downloading" : cancelled ? "available" : "failed", installed: false, updatedAt: Date.now() });
    if (!cancelled) await logError("model-download", error, model.name);
    throw error;
  }
}

export async function downloadTask(
  taskId: string,
  onProgress?: (task: DownloadTask) => void,
  signal?: AbortSignal,
) {
  const task = await db.downloads.get(taskId);
  if (!task) throw new Error("Download task not found.");
  const releaseBusy = beginBusy("model-download");
  const controller = new AbortController();
  activeDownloadControllers.set(taskId, controller);
  const relayAbort = () => controller.abort();
  signal?.addEventListener("abort", relayAbort, { once: true });
  try {
    return await withModelLock(task.modelId, () => downloadTaskUnlocked(taskId, onProgress, controller.signal));
  } finally {
    releaseBusy();
    activeDownloadControllers.delete(taskId);
    signal?.removeEventListener("abort", relayAbort);
  }
}

export async function pauseDownload(taskId: string) {
  pauseRequested.add(taskId);
  activeDownloadControllers.get(taskId)?.abort();
  if (!activeDownloadControllers.has(taskId)) {
    pauseRequested.delete(taskId);
    await db.downloads.update(taskId, { state: "paused", updatedAt: Date.now() });
  }
}

export async function cancelDownload(taskId: string) {
  pauseRequested.delete(taskId);
  activeDownloadControllers.get(taskId)?.abort();
  const task = await db.downloads.get(taskId);
  if (task) {
    await db.downloads.update(taskId, { state: "cancelled", updatedAt: Date.now() });
    await db.browserModels.update(task.modelId, { status: "available", installed: false, updatedAt: Date.now() });
  }
}

export async function resumeDownload(taskId: string, onProgress?: (task: DownloadTask) => void) {
  return downloadTask(taskId, onProgress);
}

export async function removeBrowserModel(id: string) {
  const model = await db.browserModels.get(id);
  if (!model) return;
  if (model.opfsPath) await deleteOpfs(model.opfsPath).catch(() => undefined);
  await db.downloads.where("modelId").equals(id).delete();

  if (model.source === "huggingface" && model.sourceUrl) {
    await db.browserModels.update(id, {
      installed: false,
      status: "available",
      opfsPath: undefined,
      updatedAt: Date.now(),
    });
    await logActivity("model", "Model bytes removed", `${model.name} · source manifest retained`);
    return;
  }

  await db.browserModels.delete(id);
  await logActivity("model", "Model removed", model.name);
}

export async function ensureChromeModelRecord() {
  const existing = await db.browserModels.get("chrome-ai");
  if (existing) return existing;
  const now = Date.now();
  const model: BrowserModel = {
    id: "chrome-ai",
    name: "Chrome built-in AI",
    runtime: "chrome-ai",
    source: "built-in",
    capabilities: { text: true, vision: false, embeddings: false, tools: false, audio: false },
    installed: true,
    status: "available",
    createdAt: now,
    updatedAt: now,
  };
  await db.browserModels.put(model);
  return model;
}
