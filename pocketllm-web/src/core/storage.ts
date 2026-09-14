import { db } from "../db/db";

export type StorageBucket = "models" | "documents" | "attachments" | "audio" | "downloads" | "exports" | "tmp";

function requireOpfs() {
  if (!navigator.storage?.getDirectory) {
    throw new Error("Origin Private File System is not supported by this browser.");
  }
  return navigator.storage.getDirectory();
}

async function ensureDirectory(path: string[]) {
  let dir = await requireOpfs();
  for (const part of path) {
    if (!part) continue;
    dir = await dir.getDirectoryHandle(part, { create: true });
  }
  return dir;
}

function splitPath(path: string) {
  return path.split("/").filter(Boolean);
}

function writableData(data: Blob | ArrayBuffer | Uint8Array | string): FileSystemWriteChunkType {
  if (data instanceof Uint8Array) {
    return data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
  }
  return data as FileSystemWriteChunkType;
}

export async function writeOpfs(path: string, data: Blob | ArrayBuffer | Uint8Array | string) {
  const parts = splitPath(path);
  const fileName = parts.pop();
  if (!fileName) throw new Error("Invalid OPFS path.");
  const dir = await ensureDirectory(parts);
  const handle = await dir.getFileHandle(fileName, { create: true });
  const writable = await handle.createWritable();
  await writable.write(writableData(data));
  await writable.close();
  return path;
}

export async function appendOpfs(path: string, data: Uint8Array, offset: number) {
  const parts = splitPath(path);
  const fileName = parts.pop();
  if (!fileName) throw new Error("Invalid OPFS path.");
  const dir = await ensureDirectory(parts);
  const handle = await dir.getFileHandle(fileName, { create: true });
  const writable = await handle.createWritable({ keepExistingData: true });
  await writable.seek(offset);
  await writable.write(writableData(data));
  await writable.close();
}

export async function readOpfs(path: string): Promise<File> {
  const parts = splitPath(path);
  const fileName = parts.pop();
  if (!fileName) throw new Error("Invalid OPFS path.");
  let dir = await requireOpfs();
  for (const part of parts) dir = await dir.getDirectoryHandle(part);
  const handle = await dir.getFileHandle(fileName);
  return handle.getFile();
}

export async function deleteOpfs(path: string, recursive = false) {
  const parts = splitPath(path);
  const name = parts.pop();
  if (!name) return;
  let dir = await requireOpfs();
  for (const part of parts) dir = await dir.getDirectoryHandle(part);
  await dir.removeEntry(name, { recursive });
}

export async function opfsExists(path: string) {
  try {
    await readOpfs(path);
    return true;
  } catch {
    return false;
  }
}

export async function sha256(data: Blob | ArrayBuffer) {
  const buffer = data instanceof Blob ? await data.arrayBuffer() : data;
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function walkDirectory(dir: FileSystemDirectoryHandle): Promise<number> {
  let total = 0;
  for await (const [, handle] of (dir as any).entries() as AsyncIterable<[string, FileSystemHandle]>) {
    if (handle.kind === "file") {
      total += (await (handle as FileSystemFileHandle).getFile()).size;
    } else {
      total += await walkDirectory(handle as FileSystemDirectoryHandle);
    }
  }
  return total;
}

async function walkPaths(dir: FileSystemDirectoryHandle, prefix: string): Promise<Array<{ path: string; bytes: number }>> {
  const result: Array<{ path: string; bytes: number }> = [];
  for await (const [name, handle] of (dir as any).entries() as AsyncIterable<[string, FileSystemHandle]>) {
    const path = prefix ? `${prefix}/${name}` : name;
    if (handle.kind === "file") {
      const file = await (handle as FileSystemFileHandle).getFile();
      result.push({ path, bytes: file.size });
    } else {
      result.push(...await walkPaths(handle as FileSystemDirectoryHandle, path));
    }
  }
  return result;
}

export async function listOpfsFiles(bucket: StorageBucket) {
  try {
    const root = await requireOpfs();
    const dir = await root.getDirectoryHandle(bucket);
    return walkPaths(dir, bucket);
  } catch {
    return [];
  }
}

export async function bucketBytes(bucket: StorageBucket) {
  try {
    const root = await requireOpfs();
    const dir = await root.getDirectoryHandle(bucket);
    return walkDirectory(dir);
  } catch {
    return 0;
  }
}

export async function clearBucket(bucket: StorageBucket) {
  const root = await requireOpfs();
  try {
    await root.removeEntry(bucket, { recursive: true });
  } catch {
    // Bucket did not exist.
  }
}

export async function getStorageReport() {
  const estimate = await navigator.storage?.estimate?.();
  const persistent = (await navigator.storage?.persisted?.()) ?? false;
  const buckets = await Promise.all(
    (["models", "documents", "attachments", "audio", "downloads", "exports", "tmp"] as StorageBucket[]).map(async (name) => ({
      name,
      bytes: await bucketBytes(name),
    })),
  );
  return {
    usage: estimate?.usage ?? 0,
    quota: estimate?.quota ?? 0,
    persistent,
    buckets,
    structured: {
      chats: await db.chats.count(),
      messages: await db.messages.count(),
      documents: await db.documents.count(),
      memories: await db.memories.count(),
      logs: (await db.activity.count()) + (await db.networkAudit.count()) + (await db.errors.count()),
    },
  };
}

export async function removeOrphanedFiles() {
  const [models, documents, messages, downloads] = await Promise.all([
    db.browserModels.toArray(),
    db.documents.toArray(),
    db.messages.toArray(),
    db.downloads.toArray(),
  ]);
  const referenced = new Set<string>();
  for (const model of models) if (model.opfsPath) referenced.add(model.opfsPath);
  for (const document of documents) if (document.opfsPath) referenced.add(document.opfsPath);
  for (const task of downloads) if (task.opfsPath && ["queued", "downloading", "paused", "verifying", "installing"].includes(task.state)) referenced.add(task.opfsPath);
  for (const message of messages) {
    for (const attachment of message.attachments ?? []) if (attachment.opfsPath) referenced.add(attachment.opfsPath);
  }

  const buckets: StorageBucket[] = ["models", "documents", "attachments", "downloads", "tmp"];
  let removedFiles = 0;
  let removedBytes = 0;
  for (const bucket of buckets) {
    const files = await listOpfsFiles(bucket);
    for (const file of files) {
      if (bucket === "tmp" || !referenced.has(file.path)) {
        await deleteOpfs(file.path).catch(() => undefined);
        removedFiles += 1;
        removedBytes += file.bytes;
      }
    }
  }
  return { removedFiles, removedBytes };
}

export async function pruneLogs(days: number | null) {
  if (days === null) return { removed: 0 };
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  const before = (await db.activity.count()) + (await db.networkAudit.count()) + (await db.errors.count());
  await Promise.all([
    db.activity.where("timestamp").below(cutoff).delete(),
    db.networkAudit.where("timestamp").below(cutoff).delete(),
    db.errors.where("timestamp").below(cutoff).delete(),
  ]);
  const after = (await db.activity.count()) + (await db.networkAudit.count()) + (await db.errors.count());
  return { removed: Math.max(0, before - after) };
}

export async function clearRuntimeCaches() {
  if (!("caches" in window)) return 0;
  const names = await caches.keys();
  const targets = names.filter((name) => /pocketllm|transformers|onnx|wasm/i.test(name));
  const results = await Promise.all(targets.map((name) => caches.delete(name)));
  return results.filter(Boolean).length;
}

export async function requestPersistentStorage() {
  if (!navigator.storage?.persist) return false;
  return navigator.storage.persist();
}

export async function resetPocketLLM() {
  await Promise.all([
    clearBucket("models"),
    clearBucket("documents"),
    clearBucket("attachments"),
    clearBucket("audio"),
    clearBucket("downloads"),
    clearBucket("exports"),
    clearBucket("tmp"),
  ]);
  await db.delete();
  await db.open();
}
