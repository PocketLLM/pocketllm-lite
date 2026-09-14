import { db, ensureDefaults } from "../db/db";
import type { Chat, Message } from "./types";
import { withExclusiveLock } from "./multitab";
import { beginBusy } from "./busy";

const ITERATIONS = 600_000;
const encoder = new TextEncoder();
const decoder = new TextDecoder();

function arrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function toBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function deriveKey(password: string, salt: Uint8Array) {
  const material = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", iterations: ITERATIONS, salt: arrayBuffer(salt) },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

async function mobileChat(chat: Chat) {
  const messages = await db.messages.where("chatId").equals(chat.id).sortBy("createdAt");
  const provider = chat.providerId ? await db.providers.get(chat.providerId) : undefined;
  const browser = chat.browserModelId ? await db.browserModels.get(chat.browserModelId) : undefined;
  return {
    id: chat.id,
    title: chat.title,
    model: provider?.model || browser?.name || "web",
    messages: messages
      .filter((message) => ["user", "assistant"].includes(message.role))
      .map((message) => ({
        role: message.role,
        content: message.content,
        timestamp: new Date(message.createdAt).toISOString(),
        images: message.attachments?.filter((item) => item.imageDataUrl).map((item) => item.imageDataUrl),
        attachments: message.attachments
          ?.filter((item) => item.text)
          .map((item) => ({ name: item.name, content: item.text, sizeBytes: item.size, mimeType: item.mimeType })),
      })),
    createdAt: new Date(chat.createdAt).toISOString(),
    systemPrompt: undefined,
    systemPromptId: chat.promptId,
    temperature: chat.temperature,
    topP: chat.topP,
    topK: chat.topK,
  };
}

export async function buildBackupPayload() {
  const chats = await db.chats.toArray();
  const [personas, prompts, skills, memories, documents, notes, settings, providers, browserModels] = await Promise.all([
    db.personas.toArray(),
    db.prompts.toArray(),
    db.skills.toArray(),
    db.memories.toArray(),
    db.documents.toArray(),
    db.notes.toArray(),
    db.settings.toArray(),
    db.providers.toArray(),
    db.browserModels.toArray(),
  ]);
  const messages = await db.messages.toArray();

  return {
    schemaVersion: 3,
    appVersion: "web-0.2.0",
    exportedAt: new Date().toISOString(),
    settings: Object.fromEntries(settings.filter((row) => row.key !== "encryptedVault").map((row) => [row.key, row.value])),
    chats: await Promise.all(chats.map(mobileChat)),
    memories: memories.map((item) => ({
      ...item,
      createdAt: new Date(item.createdAt).toISOString(),
      updatedAt: new Date(item.updatedAt).toISOString(),
      lastUsedAt: item.lastUsedAt ? new Date(item.lastUsedAt).toISOString() : null,
      supersededAt: item.supersededAt ? new Date(item.supersededAt).toISOString() : null,
    })),
    personas: personas.map(({ createdAt: _createdAt, updatedAt: _updatedAt, ...rest }) => rest),
    prompts: prompts.map(({ createdAt: _createdAt, updatedAt: _updatedAt, ...rest }) => rest),
    skills: skills.map(({ createdAt: _createdAt, updatedAt: _updatedAt, ...rest }) => rest),
    documentIndex: Object.fromEntries(documents.map((document) => [document.id, {
      name: document.name,
      mimeType: document.mimeType,
      size: document.size,
      sha256: document.sha256,
      text: document.text,
      pageCount: document.pageCount,
    }])),
    web: {
      chats,
      messages,
      documents,
      notes,
      providers: providers.map((provider) => ({ ...provider, rememberSecret: false })),
      browserModels: browserModels.map((model) => ({ ...model, installed: model.runtime === "chrome-ai", opfsPath: undefined, status: model.runtime === "chrome-ai" ? model.status : "available" })),
    },
  };
}

export async function exportEncryptedBackup(password: string) {
  if (password.length < 8) throw new Error("Use a backup password with at least 8 characters.");
  const payload = await buildBackupPayload();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(password, salt);
  const encrypted = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, encoder.encode(JSON.stringify(payload))));
  const mac = encrypted.slice(-16);
  const ciphertext = encrypted.slice(0, -16);
  return JSON.stringify({
    format: "pocketllm-backup",
    version: 3,
    kdf: {
      name: "PBKDF2-HMAC-SHA256",
      iterations: ITERATIONS,
      salt: toBase64(salt),
    },
    cipher: {
      name: "AES-256-GCM",
      nonce: toBase64(nonce),
      mac: toBase64(mac),
    },
    ciphertext: toBase64(ciphertext),
  });
}

export async function decryptBackup(encryptedJson: string, password: string): Promise<any> {
  let envelope: any;
  try {
    envelope = JSON.parse(encryptedJson);
  } catch {
    throw new Error("The backup file is malformed.");
  }
  if (envelope?.format !== "pocketllm-backup" || ![2, 3].includes(envelope?.version)) throw new Error("Not a supported PocketLLM backup.");
  if (envelope?.kdf?.name !== "PBKDF2-HMAC-SHA256" || envelope?.kdf?.iterations !== ITERATIONS || envelope?.cipher?.name !== "AES-256-GCM") {
    throw new Error("Unsupported backup cryptography.");
  }
  const salt = fromBase64(envelope.kdf.salt);
  const nonce = fromBase64(envelope.cipher.nonce);
  const ciphertext = fromBase64(envelope.ciphertext);
  const mac = fromBase64(envelope.cipher.mac);
  const combined = new Uint8Array(ciphertext.length + mac.length);
  combined.set(ciphertext);
  combined.set(mac, ciphertext.length);
  const key = await deriveKey(password, salt);
  try {
    const clear = await crypto.subtle.decrypt({ name: "AES-GCM", iv: nonce }, key, combined);
    const payload = JSON.parse(decoder.decode(clear));
    if (![2, 3].includes(payload?.schemaVersion)) throw new Error("Unsupported backup payload.");
    return payload;
  } catch (error) {
    if (error instanceof Error && error.message === "Unsupported backup payload.") throw error;
    throw new Error("Incorrect password or the backup has been corrupted.");
  }
}

function validateMobilePayload(payload: any) {
  if (!Array.isArray(payload.chats) || !Array.isArray(payload.memories) || !Array.isArray(payload.personas) || !Array.isArray(payload.prompts) || !Array.isArray(payload.skills)) {
    throw new Error("Backup payload is missing required collections.");
  }
  for (const chat of payload.chats) {
    if (typeof chat?.id !== "string" || typeof chat?.title !== "string" || !Array.isArray(chat?.messages)) throw new Error("Backup contains an invalid chat.");
    for (const message of chat.messages) {
      if (typeof message?.role !== "string" || typeof message?.content !== "string" || typeof message?.timestamp !== "string") throw new Error("Backup contains an invalid message.");
      if (Number.isNaN(Date.parse(message.timestamp))) throw new Error("Backup contains an invalid message timestamp.");
    }
  }
  for (const memory of payload.memories) {
    if (typeof memory?.id !== "string" || typeof memory?.fact !== "string" || typeof memory?.createdAt !== "string") throw new Error("Backup contains an invalid memory.");
  }
}

async function restoreEncryptedBackupUnlocked(encryptedJson: string, password: string) {
  const payload = await decryptBackup(encryptedJson, password);
  validateMobilePayload(payload);

  const web = payload.web;
  const now = Date.now();

  const nextChats: Chat[] = Array.isArray(web?.chats)
    ? web.chats
    : payload.chats.map((chat: any) => ({
        id: chat.id,
        title: chat.title,
        createdAt: Date.parse(chat.createdAt) || now,
        updatedAt: Date.parse(chat.createdAt) || now,
        archived: false,
        pinned: false,
        promptId: chat.systemPromptId ?? undefined,
        temperature: chat.temperature ?? undefined,
        topP: chat.topP ?? undefined,
        topK: chat.topK ?? undefined,
      }));

  const nextMessages: Message[] = Array.isArray(web?.messages)
    ? web.messages
    : payload.chats.flatMap((chat: any) => chat.messages.map((message: any) => ({
        id: crypto.randomUUID(),
        chatId: chat.id,
        role: message.role,
        content: message.content,
        createdAt: Date.parse(message.timestamp) || now,
        attachments: [
          ...(Array.isArray(message.attachments) ? message.attachments.map((attachment: any) => ({
            id: crypto.randomUUID(),
            name: attachment.name ?? "attachment.txt",
            mimeType: attachment.mimeType ?? "text/plain",
            size: attachment.sizeBytes ?? attachment.content?.length ?? 0,
            text: attachment.content ?? "",
          })) : []),
          ...(Array.isArray(message.images) ? message.images.map((image: string, index: number) => ({
            id: crypto.randomUUID(),
            name: `image-${index + 1}`,
            mimeType: "image/*",
            size: image.length,
            imageDataUrl: image,
          })) : []),
        ],
      })));

  const nextMemories = payload.memories.map((item: any) => ({
    ...item,
    createdAt: Date.parse(item.createdAt) || now,
    updatedAt: Date.parse(item.updatedAt ?? item.createdAt) || now,
    lastUsedAt: item.lastUsedAt ? Date.parse(item.lastUsedAt) : undefined,
    supersededAt: item.supersededAt ? Date.parse(item.supersededAt) : undefined,
  }));
  const nextPersonas = payload.personas.map((item: any) => ({ ...item, createdAt: now, updatedAt: now }));
  const nextPrompts = payload.prompts.map((item: any) => ({ ...item, createdAt: now, updatedAt: now }));
  const nextSkills = payload.skills.map((item: any) => ({ ...item, createdAt: now, updatedAt: now }));

  const nextDocuments = Array.isArray(web?.documents)
    ? web.documents.map((item: any) => ({ ...item, opfsPath: undefined }))
    : Object.entries(payload.documentIndex ?? {}).map(([id, item]: [string, any]) => ({
        id,
        name: item.name ?? id,
        mimeType: item.mimeType ?? "text/plain",
        size: item.size ?? item.text?.length ?? 0,
        sha256: item.sha256 ?? "backup",
        text: item.text ?? "",
        pageCount: item.pageCount,
        chunkCount: 0,
        retrievalMode: "keyword",
        createdAt: now,
        updatedAt: now,
      }));

  const settingsEntries = Object.entries(payload.settings ?? {}).filter(([key]) => key !== "encryptedVault").map(([key, value]) => ({ key, value }));

  await db.transaction(
    "rw",
    [db.chats, db.messages, db.memories, db.personas, db.prompts, db.skills, db.documents, db.documentChunks, db.notes, db.providers, db.browserModels, db.settings],
    async () => {
      await Promise.all([
        db.chats.clear(),
        db.messages.clear(),
        db.memories.clear(),
        db.personas.clear(),
        db.prompts.clear(),
        db.skills.clear(),
        db.documents.clear(),
        db.documentChunks.clear(),
        db.notes.clear(),
        db.providers.clear(),
        db.browserModels.clear(),
        db.settings.clear(),
      ]);
      if (nextChats.length) await db.chats.bulkAdd(nextChats);
      if (nextMessages.length) await db.messages.bulkAdd(nextMessages);
      if (nextMemories.length) await db.memories.bulkAdd(nextMemories);
      if (nextPersonas.length) await db.personas.bulkAdd(nextPersonas);
      if (nextPrompts.length) await db.prompts.bulkAdd(nextPrompts);
      if (nextSkills.length) await db.skills.bulkAdd(nextSkills);
      if (nextDocuments.length) await db.documents.bulkAdd(nextDocuments);
      if (Array.isArray(web?.notes) && web.notes.length) await db.notes.bulkAdd(web.notes);
      if (Array.isArray(web?.providers) && web.providers.length) await db.providers.bulkAdd(web.providers);
      if (Array.isArray(web?.browserModels) && web.browserModels.length) await db.browserModels.bulkAdd(web.browserModels);
      if (settingsEntries.length) await db.settings.bulkPut(settingsEntries);
    },
  );
  await ensureDefaults();
  return {
    chats: nextChats.length,
    messages: nextMessages.length,
    memories: nextMemories.length,
    personas: nextPersonas.length,
    prompts: nextPrompts.length,
    skills: nextSkills.length,
    documents: nextDocuments.length,
  };
}

export async function restoreEncryptedBackup(encryptedJson: string, password: string) {
  const releaseBusy = beginBusy("backup-restore");
  try {
    return await withExclusiveLock("backup-restore", () => restoreEncryptedBackupUnlocked(encryptedJson, password));
  } finally {
    releaseBusy();
  }
}

export function downloadBackup(json: string) {
  const blob = new Blob([json], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `pocketllm-${new Date().toISOString().slice(0, 10)}.pllm`;
  link.click();
  URL.revokeObjectURL(url);
}
