'use client';

/**
 * About — app identity, measured browser capabilities, honest limits
 * of this web build, and tech credits.
 */
import { useEffect, useState } from 'react';
import {
  CheckCircle2,
  ExternalLink,
  XCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Section, StatusDot } from '@/features/app/shared/ui';
import { capabilityProbe, type Capabilities } from '@/lib/core/net/capabilities';
import { APP_VERSION, formatRelativeTime } from '@/lib/utils';

const HONEST_LIMITS = [
  'An embedded OpenAI-compatible server — connect your own endpoint instead.',
  'Guaranteed reminders while the browser is closed — background scheduling is up to your OS notifications.',
  'Hardware-backed key storage — this browser has no secure keychain; API keys live in memory for the session.',
  'Full hardware telemetry — the app only measures what runtime decisions need (cores, memory, storage).',
];

const TECH_CREDITS = [
  'Next.js (App Router)',
  'Tailwind CSS',
  'shadcn/ui + Radix',
  'lucide-react icons',
  'IndexedDB + OPFS',
  'Web Crypto (PBKDF2 · AES-GCM)',
];

export function AboutSettings() {
  const [caps, setCaps] = useState<Capabilities | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    capabilityProbe
      .scan()
      .then((c) => !cancelled && setCaps(c))
      .catch((err) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const capRows: Array<{ label: string; node: React.ReactNode }> = caps
    ? [
        {
          label: 'WebGPU',
          node: (
            <StatusDot tone={caps.webgpu ? 'success' : 'error'}>
              {caps.webgpu ? 'available' : 'not available'}
            </StatusDot>
          ),
        },
        {
          label: 'WASM SIMD',
          node: (
            <StatusDot tone={caps.wasmSimd ? 'success' : 'error'}>
              {caps.wasmSimd ? 'available' : 'not available'}
            </StatusDot>
          ),
        },
        {
          label: 'OPFS (local model storage)',
          node: (
            <StatusDot tone={caps.opfs ? 'success' : 'error'}>
              {caps.opfs ? 'available' : 'not available'}
            </StatusDot>
          ),
        },
        {
          label: 'Cross-origin isolated',
          node: (
            <StatusDot tone={caps.crossOriginIsolated ? 'success' : 'neutral'}>
              {caps.crossOriginIsolated ? 'yes' : 'no'}
            </StatusDot>
          ),
        },
        {
          label: 'CPU threads',
          node: (
            <span className="font-mono text-xs text-muted-foreground">
              {caps.hardwareConcurrency}
            </span>
          ),
        },
        {
          label: 'Device memory',
          node: (
            <span className="font-mono text-xs text-muted-foreground">
              {caps.deviceMemoryGb !== null ? `≥ ${caps.deviceMemoryGb} GB` : 'unknown'}
            </span>
          ),
        },
        {
          label: 'Storage persisted',
          node: (
            <StatusDot tone={caps.storagePersisted ? 'success' : 'warning'}>
              {caps.storagePersisted ? 'granted' : 'best-effort'}
            </StatusDot>
          ),
        },
        {
          label: 'Chrome built-in AI',
          node: (
            <StatusDot
              tone={
                caps.chromeBuiltInAI === 'available'
                  ? 'success'
                  : caps.chromeBuiltInAI === 'unavailable'
                    ? 'warning'
                    : 'neutral'
              }
            >
              {caps.chromeBuiltInAI === 'available'
                ? 'available'
                : caps.chromeBuiltInAI === 'unavailable'
                  ? 'unavailable (model not ready)'
                  : 'unsupported (not this browser)'}
            </StatusDot>
          ),
        },
        {
          label: 'Speech recognition',
          node: (
            <StatusDot tone={caps.speechRecognition === 'available' ? 'success' : 'neutral'}>
              {caps.speechRecognition}
            </StatusDot>
          ),
        },
        {
          label: 'Notifications',
          node: (
            <StatusDot
              tone={
                caps.notifications === 'granted'
                  ? 'success'
                  : caps.notifications === 'unsupported'
                    ? 'neutral'
                    : 'warning'
              }
            >
              {caps.notifications === 'unsupported' ? 'unsupported' : caps.notifications}
            </StatusDot>
          ),
        },
      ]
    : [];

  return (
    <div className="space-y-6">
      {/* ------------------------------ identity ----------------------------- */}
      <Section>
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex min-w-0 items-center gap-4">
            { }
            <img
              src="/logo.png"
              alt="PocketLLM logo"
              className="h-12 w-12 rounded-xl border border-border"
            />
            <div className="min-w-0">
              <h2 className="font-display text-lg font-semibold">PocketLLM Lite</h2>
              <p className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-muted-foreground">
                <span className="rounded bg-muted px-1.5 py-0.5 font-mono">
                  v{APP_VERSION}
                </span>
                <span>MIT License</span>
              </p>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="outline" size="sm" asChild>
              <a
                href="https://github.com/PocketLLM/pocketllm-lite"
                target="_blank"
                rel="noopener noreferrer"
              >
                GitHub
                <ExternalLink aria-hidden />
              </a>
            </Button>
            <Button variant="ghost" size="sm" asChild>
              <a
                href="https://github.com/PocketLLM/pocketllm-lite/issues"
                target="_blank"
                rel="noopener noreferrer"
              >
                Issues
                <ExternalLink aria-hidden />
              </a>
            </Button>
          </div>
        </div>
      </Section>

      {/* ---------------------------- capabilities --------------------------- */}
      <Section
        title="Capabilities"
        description="Measured on this browser just now — nothing is inferred from the user agent."
      >
        {error ? (
          <p className="text-[13px] text-destructive" role="alert">
            Capability probe failed: {error}
          </p>
        ) : caps === null ? (
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="h-6 w-full" />
            ))}
          </div>
        ) : (
          <>
            <dl className="divide-y divide-border">
              {capRows.map((row) => (
                <div
                  key={row.label}
                  className="flex items-center justify-between gap-4 py-2"
                >
                  <dt className="text-[13px]">{row.label}</dt>
                  <dd>{row.node}</dd>
                </div>
              ))}
            </dl>
            <p className="mt-3 text-xs text-muted-foreground">
              {caps.browser} on {caps.platform} · {caps.language} · probed{' '}
              {formatRelativeTime(caps.scannedAt)}
            </p>
          </>
        )}
      </Section>

      {/* ----------------------------- honest limits ------------------------ */}
      <Section
        title="What this web build honestly cannot do"
        description="Stated up front rather than discovered later."
      >
        <ul className="space-y-2.5">
          {HONEST_LIMITS.map((limit) => (
            <li key={limit} className="flex items-start gap-2.5">
              <XCircle className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
              <span className="text-[13px] leading-relaxed">{limit}</span>
            </li>
          ))}
        </ul>
      </Section>

      {/* ------------------------------ credits ----------------------------- */}
      <Section title="Tech credits" description="Everything below runs locally in your browser.">
        <ul className="flex flex-wrap gap-1.5">
          {TECH_CREDITS.map((tech) => (
            <li
              key={tech}
              className="inline-flex items-center gap-1.5 rounded-full border border-border px-2.5 py-0.5 text-[11px] text-muted-foreground"
            >
              <CheckCircle2 className="h-3 w-3" aria-hidden />
              {tech}
            </li>
          ))}
        </ul>
      </Section>
    </div>
  );
}
