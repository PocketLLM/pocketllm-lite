/**
 * SettingsService — canonical application settings.
 *
 * Settings live in localStorage for synchronous hydration at boot
 * (the app shell must render with correct theme/strict-offline state
 * before IndexedDB resolves). A domain event fires on every change so
 * React stores stay in sync. The NetworkGateway's policy holder is
 * refreshed from here.
 */
import { bus } from '@/lib/core/events/event-bus';
import { policyHolder } from '@/lib/core/net/network-gateway';
import type { AppSettings } from '@/lib/types/domain';
import { deepMerge } from '@/lib/utils';

const STORAGE_KEY = 'pocketllm.settings.v1';

export const DEFAULT_SETTINGS: AppSettings = {
  general: {
    displayName: '',
    sendOnEnter: true,
    compactMode: false,
    reduceMotion: false,
  },
  appearance: {
    theme: 'system',
    fontSize: 'md',
    accent: 'sandy',
  },
  chat: {
    defaultRuntimeId: 'assist',
    defaultModelId: 'pocketllm-assist',
    showTokenCounters: true,
    streamingEnabled: true,
    autoTitle: true,
    maxContextMessages: 30,
    showTimestamps: 'hover',
    followUpSuggestions: true,
    jkHintDismissed: false,
  },
  memory: {
    enabled: true,
    autoExtract: true,
    maxMemoriesInPrompt: 8,
    minConfidence: 0.5,
  },
  knowledge: {
    defaultRetrievalMode: 'hybrid',
    chunkSize: 900,
    topK: 5,
  },
  tools: {
    calculator: true,
    notes: true,
    clipboard: true,
    webSearch: true,
    draftEmail: true,
    openUrl: true,
    deviceInfo: true,
    webhook: false,
    requireConfirmation: true,
  },
  privacy: {
    strictOffline: false,
    allowLoopback: true,
    allowLan: false,
    auditNetwork: true,
  },
  network: {
    allowedPurposes: [
      'assist-inference',
      'assist-vision',
      'assist-enhance',
      'assist-title',
      'assist-memory',
      'assist-search',
      'assist-asr',
      'ollama-loopback',
      'update-check',
    ],
  },
  language: {
    locale: typeof navigator !== 'undefined' ? navigator.language : 'en',
  },
  search: {
    savedQueries: [],
  },
  storage: {
    logRetentionDays: 30,
  },
  meta: {
    schemaVersion: 1,
    setupCompleted: false,
  },
};

class SettingsService {
  private cache: AppSettings | null = null;

  /** Hydrated settings — falls back to defaults when unreadable. */
  get(): AppSettings {
    if (this.cache) return this.cache;
    let hydrated: AppSettings = structuredClone(DEFAULT_SETTINGS);
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        // deepMerge keeps unknown stored keys out of the typed shape.
        hydrated = deepMerge(
          structuredClone(DEFAULT_SETTINGS) as unknown as Record<string, unknown>,
          JSON.parse(raw) as Record<string, unknown>
        ) as unknown as AppSettings;
      }
    } catch {
      // Corrupt JSON — fall back to defaults.
    }
    this.cache = hydrated;
    this.syncNetworkPolicy();
    return this.cache;
  }

  /** Shallow-deep patch; persists and notifies subscribers. */
  patch(patch: Record<string, unknown>): AppSettings {
    const next = deepMerge(this.get() as unknown as Record<string, unknown>, patch);
    this.cache = next as unknown as AppSettings;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch (err) {
      console.error('[settings] persist failed', err);
    }
    this.syncNetworkPolicy();
    bus.emit('settings:changed');
    return this.cache;
  }

  replaceAll(next: AppSettings): void {
    this.cache = next;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch (err) {
      console.error('[settings] persist failed', err);
    }
    this.syncNetworkPolicy();
    bus.emit('settings:changed');
  }

  reset(): AppSettings {
    localStorage.removeItem(STORAGE_KEY);
    this.cache = structuredClone(DEFAULT_SETTINGS);
    this.syncNetworkPolicy();
    bus.emit('settings:changed');
    return this.cache;
  }

  /** Pushes the privacy policy into the NetworkGateway. */
  private syncNetworkPolicy(): void {
    const p = this.get().privacy;
    policyHolder.update({
      strictOffline: p.strictOffline,
      allowLoopback: p.allowLoopback,
      allowLan: p.allowLan,
      auditNetwork: p.auditNetwork,
    });
  }
}

export const settingsService = new SettingsService();
