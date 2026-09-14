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

export async function writeOpfs(path: string, data: Blob | ArrayBuffer | Uint8Array | string) {
  const parts = splitPath(path);
  const fileName = parts.pop();
  if (!fileName) throw new Error("Invalid OPFS path.");
  const dir = await ensureDirectory(parts);
  const handle = await dir.getFileHandle(fileName, { create: true });
  const writable = await handle.createWritable();
  await writable.write(data);
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
  await writable.write(data);
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
  for await (const [, handle] of dir.entries()) {
    if (handle.kind === "file") {
      total += (await (handle as FileSystemFileHandle).getFile()).size;
    } else {
      total += await walkDirectory(handle as FileSystemDirectoryHandle);
    }
  }
  return total;
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
