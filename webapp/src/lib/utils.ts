/**
 * Shared utilities: ids, formatting, tokens, time.
 */
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** RFC4122-ish v4 UUID with crypto randomness. */
export function uuid(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/* --------------------------- formatting --------------------------- */

export function formatBytes(bytes: number, decimals = 1): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    units.length - 1
  );
  return `${(bytes / Math.pow(1024, i)).toFixed(decimals)} ${units[i]}`;
}

export function formatNumber(n: number): string {
  return new Intl.NumberFormat().format(n);
}

export function formatRelativeTime(ts: number): string {
  const diff = Date.now() - ts;
  const min = 60_000;
  const hour = 60 * min;
  const day = 24 * hour;
  if (diff < min) return 'just now';
  if (diff < hour) return `${Math.floor(diff / min)}m ago`;
  if (diff < day) return `${Math.floor(diff / hour)}h ago`;
  if (diff < 7 * day) return `${Math.floor(diff / day)}d ago`;
  return new Date(ts).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: new Date(ts).getFullYear() === new Date().getFullYear()
      ? undefined
      : 'numeric',
  });
}

export function formatDuration(ms: number): string {
  if (ms < 1000) return `${Math.round(ms)}ms`;
  if (ms < 60_000) return `${(ms / 1000).toFixed(1)}s`;
  const m = Math.floor(ms / 60_000);
  const s = Math.round((ms % 60_000) / 1000);
  return `${m}m ${s}s`;
}

export function formatClock(ts: number): string {
  return new Date(ts).toLocaleTimeString(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** Groups timestamps into Today / Yesterday / weekday / date buckets. */
export function dateBucket(ts: number): string {
  const now = new Date();
  const d = new Date(ts);
  const startOfToday = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate()
  ).getTime();
  if (ts >= startOfToday) return 'Today';
  if (ts >= startOfToday - 86_400_000) return 'Yesterday';
  if (ts >= startOfToday - 7 * 86_400_000)
    return d.toLocaleDateString(undefined, { weekday: 'long' });
  return d.toLocaleDateString(undefined, {
    month: 'long',
    day: 'numeric',
    year: d.getFullYear() === now.getFullYear() ? undefined : 'numeric',
  });
}

/* ----------------------------- tokens ----------------------------- */

/** Rough token estimate (~4 chars/token) — labelled as estimated in UI. */
export function estimateTokens(text: string): number {
  return Math.ceil((text ?? '').length / 4);
}

/* ----------------------------- misc ------------------------------- */

export function debounce<A extends unknown[]>(
  fn: (...args: A) => void,
  waitMs: number
): ((...args: A) => void) & { flush: () => void } {
  let timer: ReturnType<typeof setTimeout> | null = null;
  let lastArgs: A | null = null;
  const wrapped = (...args: A) => {
    lastArgs = args;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = null;
      if (lastArgs) fn(...lastArgs);
    }, waitMs);
  };
  wrapped.flush = () => {
    if (timer) clearTimeout(timer);
    timer = null;
    if (lastArgs) fn(...lastArgs);
  };
  return wrapped;
}

export function greetingForHour(date = new Date()): string {
  const h = date.getHours();
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 22) return 'Good evening';
  return 'Good night';
}

/** Safe, deep-ish merge for settings patches. */
export function deepMerge<T extends Record<string, unknown>>(
  base: T,
  patch: Record<string, unknown>
): T {
  const out = { ...base } as Record<string, unknown>;
  for (const [k, v] of Object.entries(patch ?? {})) {
    if (
      v &&
      typeof v === 'object' &&
      !Array.isArray(v) &&
      typeof out[k] === 'object' &&
      !Array.isArray(out[k])
    ) {
      out[k] = deepMerge(
        out[k] as Record<string, unknown>,
        v as Record<string, unknown>
      );
    } else if (v !== undefined) {
      out[k] = v;
    }
  }
  return out as T;
}

export const APP_VERSION = '1.0.38-web';
