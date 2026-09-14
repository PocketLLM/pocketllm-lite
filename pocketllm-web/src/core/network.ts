import { db, setting } from "../db/db";
import type { NetworkAudit } from "./types";

export type NetworkPurpose =
  | "ollama-loopback"
  | "ollama-lan"
  | "remote-inference"
  | "huggingface-search"
  | "huggingface-download"
  | "web-search"
  | "github-skill"
  | "update-check"
  | "external-resource"
  | "webhook"
  | "provider-test";

function isPrivateIpv4(host: string) {
  const parts = host.split(".").map(Number);
  if (parts.length !== 4 || parts.some((part) => Number.isNaN(part))) return false;
  return (
    parts[0] === 10 ||
    parts[0] === 127 ||
    (parts[0] === 192 && parts[1] === 168) ||
    (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31)
  );
}

export function classifyDestination(input: string): NetworkAudit["scope"] {
  const url = new URL(input, location.href);
  const host = url.hostname.toLowerCase();
  if (host === "localhost" || host === "::1" || host === "[::1]" || host === "127.0.0.1") return "loopback";
  if (
    isPrivateIpv4(host) ||
    host.endsWith(".local") ||
    host.startsWith("169.254.") ||
    host.startsWith("fe80:")
  ) return "lan";
  return "internet";
}

async function audit(destination: string, purpose: string, allowed: boolean, blockReason?: string) {
  let scope: NetworkAudit["scope"] = "internet";
  try {
    scope = classifyDestination(destination);
  } catch {
    // Invalid URLs are treated as internet and fail below.
  }
  await db.networkAudit.add({
    id: crypto.randomUUID(),
    timestamp: Date.now(),
    destination: (() => {
      try {
        const url = new URL(destination, location.href);
        return `${url.protocol}//${url.host}`;
      } catch {
        return destination.slice(0, 160);
      }
    })(),
    scope,
    purpose,
    allowed,
    blockReason,
  });
}

export class NetworkPolicyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "NetworkPolicyError";
  }
}

export async function networkFetch(
  input: string | URL,
  init: RequestInit = {},
  purpose: NetworkPurpose,
) {
  const destination = String(input);
  const scope = classifyDestination(destination);
  const strictOffline = await setting("strictOffline", false);

  if (strictOffline && scope !== "loopback") {
    const reason = `Strict Offline blocks ${scope} network access.`;
    await audit(destination, purpose, false, reason);
    throw new NetworkPolicyError(reason);
  }

  try {
    const response = await fetch(input, init);
    await audit(destination, purpose, true);
    return response;
  } catch (error) {
    await audit(destination, purpose, false, error instanceof Error ? error.message : "Network request failed");
    throw error;
  }
}

export async function clearNetworkAudit() {
  await db.networkAudit.clear();
}
