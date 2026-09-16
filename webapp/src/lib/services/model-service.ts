/**
 * ModelService — curated browser-model catalogue, installed model
 * manifests, and the resumable download manager (real bytes into
 * OPFS, SHA-256 verification, ETag/Last-Modified validators).
 *
 * Download states: queued → downloading → (paused) → verifying →
 * installing → ready | failed | cancelled.
 *
 * Resume rule (matching the mobile app): a resumed request only
 * appends when the server proves Range support AND validators match.
 * A full HTTP 200 on a resume restarts from byte zero.
 */
import { bus } from '@/lib/core/events/event-bus';
import { downloadRepo, modelRepo } from '@/lib/core/db/repositories';
import { gateway } from '@/lib/core/net/network-gateway';
import { backupCrypto } from '@/lib/core/crypto/backup-crypto';
import { logService } from './log-service';
import type {
  DownloadState,
  DownloadTask,
  ModelCatalogEntry,
  ModelManifest,
  UUID,
} from '@/lib/types/domain';
import { formatBytes, uuid } from '@/lib/utils';

/* ------------------------- curated catalogue ------------------------ */
/**
 * Curated compatibility catalogue — small, split-file-friendly GGUF
 * entries, honestly annotated. Sizes/quantization reflect upstream
 * releases; capabilities stay "unknown" until verified on-device.
 */
export const MODEL_CATALOG: ModelCatalogEntry[] = [
  {
    id: 'qwen2.5-0.5b-instruct-q4-k-m',
    name: 'Qwen2.5 0.5B Instruct',
    author: 'Qwen',
    tier: 'tiny',
    quantization: 'Q4_K_M',
    paramsClass: '0.5B',
    contextLimit: 32768,
    sizeBytes: 400_000_000,
    license: 'Apache-2.0',
    repoUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Sub-500M class model that runs on CPU/WASM. Best starting point for browser-local inference on modest hardware.',
  },
  {
    id: 'llama-3.2-1b-instruct-q4-k-m',
    name: 'Llama 3.2 1B Instruct',
    author: 'Meta',
    tier: 'small',
    quantization: 'Q4_K_M',
    paramsClass: '1B',
    contextLimit: 131072,
    sizeBytes: 808_000_000,
    license: 'llama-3.2',
    repoUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'The default browser-local option: strong quality for its size, needs WebGPU for comfortable speed.',
  },
  {
    id: 'qwen2.5-1.5b-instruct-q4-k-m',
    name: 'Qwen2.5 1.5B Instruct',
    author: 'Qwen',
    tier: 'small',
    quantization: 'Q4_K_M',
    paramsClass: '1.5B',
    contextLimit: 32768,
    sizeBytes: 1_060_000_000,
    license: 'Apache-2.0',
    repoUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Capable mid-small model for desktop browsers with WebGPU. Tool-calling behavior unverified.',
  },
  {
    id: 'smollm2-360m-instruct-q8',
    name: 'SmolLM2 360M Instruct',
    author: 'HuggingFaceTB',
    tier: 'tiny',
    quantization: 'Q8_0',
    paramsClass: '0.36B',
    contextLimit: 8192,
    sizeBytes: 390_000_000,
    license: 'apache-2.0',
    repoUrl: 'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Tiny instruct model tuned for on-device use. Very low memory ceiling, modest quality.',
  },
  {
    id: 'qwen2.5-3b-instruct-q4-k-m',
    name: 'Qwen2.5 3B Instruct',
    author: 'Qwen',
    tier: 'medium',
    quantization: 'Q4_K_M',
    paramsClass: '3B',
    contextLimit: 32768,
    sizeBytes: 1_990_000_000,
    license: 'Apache-2.0',
    repoUrl: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Capable desktop/WebGPU tier. Large download — only recommended with plenty of storage and a discrete GPU.',
  },
  {
    id: 'gemma-2-2b-it-q4-k-m',
    name: 'Gemma 2 2B IT',
    author: 'Google',
    tier: 'small',
    quantization: 'Q4_K_M',
    paramsClass: '2B',
    contextLimit: 8192,
    sizeBytes: 1_670_000_000,
    license: 'gemma',
    repoUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF',
    downloadUrl:
      'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Google\u2019s 2B instruct model. Strong quality for its class; needs WebGPU for usable speed in the browser.',
  },
  {
    id: 'tinyllama-1.1b-chat-v1.0-q4-k-m',
    name: 'TinyLlama 1.1B Chat',
    author: 'TinyLlama',
    tier: 'tiny',
    quantization: 'Q4_K_M',
    paramsClass: '1.1B',
    contextLimit: 2048,
    sizeBytes: 669_000_000,
    license: 'apache-2.0',
    repoUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
    downloadUrl:
      'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Very small chat model with a short context window. A lightweight fallback for constrained devices.',
  },
  {
    id: 'llama-3.2-3b-instruct-q4-k-m',
    name: 'Llama 3.2 3B Instruct',
    author: 'Meta',
    tier: 'medium',
    quantization: 'Q4_K_M',
    paramsClass: '3B',
    contextLimit: 131072,
    sizeBytes: 1_970_000_000,
    license: 'llama-3.2',
    repoUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Meta\u2019s 3B tier with a 128k context window. Noticeably stronger reasoning than the 1B — desktop WebGPU recommended.',
  },
  {
    id: 'qwen2.5-coder-1.5b-instruct-q4-k-m',
    name: 'Qwen2.5 Coder 1.5B Instruct',
    author: 'Qwen',
    tier: 'small',
    quantization: 'Q4_K_M',
    paramsClass: '1.5B',
    contextLimit: 32768,
    sizeBytes: 1_080_000_000,
    license: 'Apache-2.0',
    repoUrl: 'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Code-specialist fine-tune: strong at filling, explaining and refactoring snippets inside the browser.',
  },
  {
    id: 'phi-3.5-mini-instruct-q4-k-m',
    name: 'Phi-3.5 Mini Instruct',
    author: 'Microsoft',
    tier: 'medium',
    quantization: 'Q4_K_M',
    paramsClass: '3.8B',
    contextLimit: 131072,
    sizeBytes: 2_380_000_000,
    license: 'MIT',
    repoUrl: 'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'Compact 3.8B reasoning model, MIT-licensed. Large download — best on desktops with WebGPU and spare storage.',
  },
  {
    id: 'smollm2-1.7b-instruct-q8',
    name: 'SmolLM2 1.7B Instruct',
    author: 'HuggingFaceTB',
    tier: 'small',
    quantization: 'Q8_0',
    paramsClass: '1.7B',
    contextLimit: 8192,
    sizeBytes: 1_790_000_000,
    license: 'apache-2.0',
    repoUrl: 'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF',
    downloadUrl:
      'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q8_0.gguf',
    capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
    runtimes: ['browser-gguf'],
    description:
      'The 1.7B sibling of the 360M entry at higher precision (Q8). Balanced quality for on-device chat.',
  },
];

/* --------------------------- download manager ----------------------- */

class ModelService {
  private activeTasks = new Map<UUID, AbortController>();

  catalog(): ModelCatalogEntry[] {
    return MODEL_CATALOG;
  }

  catalogEntry(id: string): ModelCatalogEntry | undefined {
    return MODEL_CATALOG.find((m) => m.id === id);
  }

  async installed(): Promise<ModelManifest[]> {
    const all = await modelRepo.getAll();
    return all
      .filter((m) => !m.deleted)
      .sort((a, b) => b.downloadedAt - a.downloadedAt);
  }

  async listDownloads(): Promise<DownloadTask[]> {
    const all = await downloadRepo.getAll();
    return all.sort((a, b) => b.updatedAt - a.updatedAt);
  }

  /** Kicks off (or resumes) a catalog model download. */
  async startDownload(catalogId: string): Promise<DownloadTask> {
    const entry = this.catalogEntry(catalogId);
    if (!entry) throw new Error('Unknown catalog model');
    const existing = (await downloadRepo.getAll()).find(
      (d) => d.modelCatalogId === catalogId &&
        !['ready', 'failed', 'cancelled'].includes(d.state)
    );
    if (existing) return existing;

    const task: DownloadTask = {
      id: uuid(),
      modelCatalogId: catalogId,
      url: entry.downloadUrl,
      filename: entry.downloadUrl.split('/').pop() ?? `${catalogId}.gguf`,
      state: 'queued',
      bytesDownloaded: 0,
      bytesTotal: entry.sizeBytes,
      expectedSha256: entry.sha256,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    await downloadRepo.put(task);
    bus.emit('downloads:changed');
    void this.runDownload(task.id);
    return task;
  }

  pause(id: UUID): void {
    this.activeTasks.get(id)?.abort();
    this.activeTasks.delete(id);
  }

  async resume(id: UUID): Promise<void> {
    const task = await downloadRepo.get(id);
    if (!task || task.state !== 'paused') return;
    task.state = 'downloading';
    task.updatedAt = Date.now();
    await downloadRepo.put(task);
    bus.emit('downloads:changed');
    void this.runDownload(id);
  }

  async cancel(id: UUID): Promise<void> {
    this.activeTasks.get(id)?.abort();
    this.activeTasks.delete(id);
    const task = await downloadRepo.get(id);
    if (!task) return;
    task.state = 'cancelled';
    task.updatedAt = Date.now();
    await downloadRepo.put(task);
    bus.emit('downloads:changed');
  }

  /** Deletes model bytes; a lightweight manifest stays for re-download. */
  async deleteModel(id: UUID): Promise<void> {
    const manifest = await modelRepo.get(id);
    if (!manifest) return;
    if (manifest.storagePath) {
      const { opfs } = await import('./document-service');
      await opfs.remove(manifest.storagePath);
    }
    await modelRepo.delete(id);
    bus.emit('models:changed');
    void logService.recordActivity(
      'model.deleted',
      `${manifest.name} · ${formatBytes(manifest.sizeBytes)} freed`
    );
  }

  /* ------------------------ download internals ------------------------ */

  private async runDownload(taskId: UUID): Promise<void> {
    const task = await downloadRepo.get(taskId);
    if (!task) return;
    const entry = this.catalogEntry(task.modelCatalogId);
    if (!entry) return;

    const abort = new AbortController();
    this.activeTasks.set(taskId, abort);
    const patch = async (p: Partial<DownloadTask>) => {
      Object.assign(task, p, { updatedAt: Date.now() });
      await downloadRepo.put(task);
      bus.emit('downloads:changed');
    };

    try {
      await patch({ state: 'downloading' });

      // OPFS staging file.
      const root = await navigator.storage.getDirectory();
      const dir = await root.getDirectoryHandle('models', { create: true });
      const fileHandle = await dir.getFileHandle(task.filename, { create: true });

      // Range resume only when validators prove continuity.
      const headers: Record<string, string> = {};
      let existingSize = 0;
      try {
        const existing = await fileHandle.getFile();
        existingSize = existing.size;
      } catch {
        existingSize = 0;
      }
      const canResume =
        existingSize > 0 &&
        existingSize < task.bytesTotal &&
        (task.etag || task.lastModified);
      if (canResume) {
        headers.Range = `bytes=${existingSize}-`;
        if (task.etag) headers['If-Range'] = task.etag;
        else if (task.lastModified) headers['If-Range'] = task.lastModified;
      }

      const res = await gateway.request('huggingface-download', task.url, {
        headers,
        signal: abort.signal,
      });

      if (!res.ok) {
        throw new Error(`Download failed with HTTP ${res.status}`);
      }

      // Validator capture.
      const etag = res.headers.get('ETag') ?? task.etag;
      const lastModified = res.headers.get('Last-Modified') ?? task.lastModified;

      // Resume correctness: a 200 on a ranged request means the server
      // ignored Range → restart from byte zero.
      let resumeWorked = false;
      if (canResume && res.status === 206) {
        resumeWorked = true;
      } else if (canResume && res.status === 200) {
        existingSize = 0;
      }

      const totalHeader = res.headers.get('Content-Length');
      const total = totalHeader
        ? existingSize + Number(totalHeader)
        : task.bytesTotal;
      task.bytesTotal = total || task.bytesTotal;

      await patch({ etag, lastModified, bytesDownloaded: existingSize });

      const writable = await fileHandle.createWritable({ keepExistingData: resumeWorked });
      if (resumeWorked) {
        await writable.seek(existingSize);
      }

      const reader = (res.body as ReadableStream<Uint8Array>).getReader();
      let downloaded = existingSize;
      let lastTick = 0;
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        // FileSystemWritableFileStream wants an ArrayBuffer-backed view;
        // copy into a fresh buffer to satisfy the DOM typings.
        const chunk = value.slice().buffer as ArrayBuffer;
        await writable.write(chunk);
        downloaded += value.byteLength;
        const now = performance.now();
        if (now - lastTick > 400) {
          lastTick = now;
          await patch({ bytesDownloaded: downloaded });
        }
      }
      await writable.close();
      await patch({ bytesDownloaded: downloaded });

      // ---- verify ----
      await patch({ state: 'verifying' });
      const file = await fileHandle.getFile();
      if (task.expectedSha256) {
        const sha = await backupCrypto.sha256Hex(file);
        if (sha !== task.expectedSha256) {
          throw new Error('SHA-256 verification failed — the download is corrupt.');
        }
      }
      // GGUF header check: bytes 0-3 must be "GGUF".
      const head = new Uint8Array(await file.slice(0, 4).arrayBuffer());
      const magic = String.fromCharCode(...head);
      if (magic !== 'GGUF') {
        throw new Error('Not a valid GGUF file (bad header).');
      }

      // ---- install ----
      await patch({ state: 'installing' });
      const manifest: ModelManifest = {
        id: uuid(),
        catalogId: entry.id,
        name: entry.name,
        runtime: 'browser-gguf',
        fileName: task.filename,
        sizeBytes: file.size,
        sha256: task.expectedSha256,
        quantization: entry.quantization,
        paramsClass: entry.paramsClass,
        contextLimit: entry.contextLimit,
        capabilities: entry.capabilities,
        storagePath: `models/${task.filename}`,
        verified: true,
        downloadedAt: Date.now(),
      };
      await modelRepo.put(manifest);
      await patch({ state: 'ready' });
      bus.emit('models:changed');
      void logService.recordActivity(
        'model.downloaded',
        `${entry.name} · ${formatBytes(file.size)}`
      );
      void logService.bumpUsage({});
    } catch (err) {
      const aborted = abort.signal.aborted;
      const message = err instanceof Error ? err.message : String(err);
      if (aborted) {
        await patch({ state: 'paused' });
      } else {
        await patch({ state: 'failed', error: message });
        void logService.recordError('models', 'download_failed', message);
      }
    } finally {
      this.activeTasks.delete(taskId);
    }
  }

  /** Imports a local GGUF file as a custom model (validates header). */
  async importLocalModel(file: File): Promise<ModelManifest> {
    const head = new Uint8Array(await file.slice(0, 4).arrayBuffer());
    if (String.fromCharCode(...head) !== 'GGUF') {
      throw new Error('This file does not have a valid GGUF header.');
    }
    const root = await navigator.storage.getDirectory();
    const dir = await root.getDirectoryHandle('models', { create: true });
    const handle = await dir.getFileHandle(file.name, { create: true });
    const writable = await handle.createWritable();
    await file.stream().pipeTo(writable);

    const manifest: ModelManifest = {
      id: uuid(),
      name: file.name.replace(/\.(gguf|GGUF)$/, ''),
      runtime: 'browser-gguf',
      fileName: file.name,
      sizeBytes: file.size,
      quantization: 'unknown',
      contextLimit: null,
      capabilities: { tools: 'unknown', vision: 'unknown', embeddings: 'unknown' },
      storagePath: `models/${file.name}`,
      verified: true,
      downloadedAt: Date.now(),
    };
    await modelRepo.put(manifest);
    bus.emit('models:changed');
    void logService.recordActivity(
      'model.downloaded',
      `Imported ${manifest.name} · ${formatBytes(file.size)}`
    );
    return manifest;
  }

  /** Storage usage for the models category (Settings → Data & Storage). */
  async storageUsage(): Promise<{ modelsBytes: number; count: number }> {
    const manifests = await this.installed();
    return {
      modelsBytes: manifests.reduce((s, m) => s + m.sizeBytes, 0),
      count: manifests.length,
    };
  }
}

export const modelService = new ModelService();
