/**
 * NetworkGateway — the single point of policy control for every
 * app-owned network request (mirrors the mobile architecture).
 *
 * Rules:
 *  - No feature may call `fetch()` directly; everything goes through
 *    `gateway.request(...)`.
 *  - Every attempt (allowed AND blocked) is recorded in the network
 *    audit log when auditing is enabled.
 *  - Strict Offline blocks everything except loopback (when allowed).
 */
import { bus } from '@/lib/core/events/event-bus';
import type { NetworkAuditEntry } from '@/lib/types/domain';

export type NetworkPurpose =
  | 'assist-inference'
  | 'assist-vision'
  | 'assist-enhance'
  | 'assist-title'
  | 'assist-memory'
  | 'assist-search'
  | 'assist-asr'
  | 'assist-suggest'
  | 'ollama-loopback'
  | 'ollama-lan'
  | 'remote-inference'
  | 'huggingface-search'
  | 'huggingface-download'
  | 'github-skill'
  | 'update-check'
  | 'external-resource'
  | 'webhook';

export interface NetworkPolicy {
  strictOffline: boolean;
  allowLoopback: boolean;
  allowLan: boolean;
  auditNetwork: boolean;
}

interface PolicySnapshot {
  getPolicy(): NetworkPolicy;
}

/** Classifies a host as loopback / lan / internet. */
export function classifyScope(url: string): 'loopback' | 'lan' | 'internet' {
  try {
    const parsed = new URL(url, window.location.origin);
    const host = parsed.hostname;
    if (
      host === 'localhost' ||
      host === '127.0.0.1' ||
      host === '::1' ||
      host === '[::1]' ||
      host === '0.0.0.0'
    ) {
      return 'loopback';
    }
    if (
      /^10\.\d+\.\d+\.\d+$/.test(host) ||
      /^192\.168\.\d+\.\d+$/.test(host) ||
      /^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/.test(host) ||
      host.endsWith('.local') ||
      host.endsWith('.lan')
    ) {
      return 'lan';
    }
    return 'internet';
  } catch {
    return 'internet';
  }
}

export class NetworkGateway {
  private policySource: PolicySnapshot;

  constructor(policySource: PolicySnapshot) {
    this.policySource = policySource;
  }

  /**
   * Decides whether a purpose+destination is allowed under the current
   * policy. Returns a reason string when blocked.
   */
  check(purpose: NetworkPurpose, url: string): { allowed: boolean; reason?: string } {
    const policy = this.policySource.getPolicy();
    const scope = classifyScope(url);

    // Same-origin API calls to this app's own backend are always fine —
    // they carry no user payload by themselves and are how the built-in
    // Assist runtime is reached.
    if (url.startsWith('/')) {
      if (policy.strictOffline) {
        // Strict Offline: built-in Assist is a hosted model — blocked.
        if (purpose.startsWith('assist-')) {
          return {
            allowed: false,
            reason: 'Strict Offline blocks the built-in Assist runtime',
          };
        }
      }
      return { allowed: true };
    }

    if (policy.strictOffline) {
      if (scope === 'loopback' && policy.allowLoopback) return { allowed: true };
      return { allowed: false, reason: 'Strict Offline is enabled' };
    }

    if (scope === 'loopback') {
      return policy.allowLoopback
        ? { allowed: true }
        : { allowed: false, reason: 'Loopback access is disabled' };
    }
    if (scope === 'lan') {
      return policy.allowLan
        ? { allowed: true }
        : { allowed: false, reason: 'LAN access is disabled' };
    }
    return { allowed: true };
  }

  /**
   * Records an entry in the network audit log (fire-and-forget, never
   * throws). Uses dynamic import to avoid a service cycle.
   */
  private audit(
    purpose: NetworkPurpose,
    destination: string,
    allowed: boolean,
    reason?: string
  ): void {
    if (!this.policySource.getPolicy().auditNetwork) return;
    import('@/lib/services/log-service').then(({ logService }) => {
      logService.recordNetwork({
        purpose,
        destination,
        allowed,
        reason,
        scope: classifyScope(destination),
      });
    });
  }

  /**
   * Policy-checked fetch. Blocked requests throw before any I/O and
   * are audited as "Blocked".
   */
  async request(
    purpose: NetworkPurpose,
    url: string,
    init?: RequestInit
  ): Promise<Response> {
    const decision = this.check(purpose, url);
    this.audit(purpose, url, decision.allowed, decision.reason);
    if (!decision.allowed) {
      throw new NetworkBlockedError(purpose, url, decision.reason);
    }
    return fetch(url, init);
  }
}

export class NetworkBlockedError extends Error {
  constructor(
    public readonly purpose: NetworkPurpose,
    public readonly destination: string,
    public readonly reason?: string
  ) {
    super(`Network request blocked: ${reason ?? 'policy'}`);
    this.name = 'NetworkBlockedError';
  }
}

/**
 * In-memory policy snapshot holder. The settings service owns the
 * canonical values; this tiny class lets the gateway read them
 * synchronously without import cycles.
 */
class PolicyHolder implements PolicySnapshot {
  private current: NetworkPolicy = {
    strictOffline: false,
    allowLoopback: true,
    allowLan: false,
    auditNetwork: true,
  };

  update(policy: NetworkPolicy): void {
    this.current = policy;
  }

  getPolicy(): NetworkPolicy {
    return this.current;
  }
}

export const policyHolder = new PolicyHolder();
export const gateway = new NetworkGateway(policyHolder);

// Re-export for the audit type used by the log service.
export type { NetworkAuditEntry };
