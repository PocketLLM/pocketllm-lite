import { db } from "../db/db";

const ITERATIONS = 600_000;
const encoder = new TextEncoder();
const decoder = new TextDecoder();

function arrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

type VaultEnvelope = {
  version: 1;
  salt: string;
  iv: string;
  ciphertext: string;
};

let unlocked: Record<string, string> | null = null;

function b64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromB64(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function keyFor(passphrase: string, salt: Uint8Array) {
  const material = await crypto.subtle.importKey("raw", encoder.encode(passphrase), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", iterations: ITERATIONS, salt: arrayBuffer(salt) },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

async function save(passphrase: string, values: Record<string, string>) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await keyFor(passphrase, salt);
  const ciphertext = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoder.encode(JSON.stringify(values))));
  const envelope: VaultEnvelope = { version: 1, salt: b64(salt), iv: b64(iv), ciphertext: b64(ciphertext) };
  await db.settings.put({ key: "encryptedVault", value: envelope });
  unlocked = { ...values };
}

export async function createOrReplaceVault(passphrase: string, values: Record<string, string>) {
  if (passphrase.length < 8) throw new Error("Use a vault passphrase with at least 8 characters.");
  await save(passphrase, values);
}

export async function unlockVault(passphrase: string) {
  const row = await db.settings.get("encryptedVault");
  if (!row?.value) {
    unlocked = {};
    return unlocked;
  }
  const envelope = row.value as VaultEnvelope;
  const key = await keyFor(passphrase, fromB64(envelope.salt));
  try {
    const clear = await crypto.subtle.decrypt({ name: "AES-GCM", iv: fromB64(envelope.iv) }, key, fromB64(envelope.ciphertext));
    unlocked = JSON.parse(decoder.decode(clear)) as Record<string, string>;
    return { ...unlocked };
  } catch {
    throw new Error("Incorrect vault passphrase or corrupted vault.");
  }
}

export function lockVault() {
  unlocked = null;
}

export function vaultGet(key: string) {
  return unlocked?.[key];
}

export async function vaultSet(key: string, value: string, passphrase: string) {
  const values: Record<string, string> = unlocked ?? await unlockVault(passphrase).catch(() => ({} as Record<string, string>));
  values[key] = value;
  await save(passphrase, values);
}

export function isVaultUnlocked() {
  return unlocked !== null;
}
