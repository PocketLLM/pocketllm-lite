'use client';

/**
 * NetworkView — the network audit centre.
 * Shows Strict Offline state, every app-owned network attempt
 * (allowed and blocked), with filters by outcome and scope.
 * Never contains prompt bodies — only purpose + destination.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ShieldCheck,
  ShieldAlert,
  Wifi,
  WifiOff,
  Trash2,
  Search,
  Globe,
  Home,
  Network as NetworkIcon,
} from 'lucide-react';
import { logService } from '@/lib/services/log-service';
import { settingsService } from '@/lib/services/settings-service';
import { bus } from '@/lib/core/events/event-bus';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import { PageHeader, Section, EmptyState } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

type OutcomeFilter = 'all' | 'allowed' | 'blocked';
type ScopeFilter = 'all' | 'loopback' | 'lan' | 'internet';

export function NetworkView() {
  const { settings } = useAppStore();
  const [entries, setEntries] = useState<Awaited<ReturnType<typeof logService.listNetworkAudit>>>([]);
  const [outcome, setOutcome] = useState<OutcomeFilter>('all');
  const [scope, setScope] = useState<ScopeFilter>('all');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setEntries(await logService.listNetworkAudit());
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
    return bus.on('networkAudit:changed', () => void load());
  }, [load]);

  const filtered = useMemo(() => {
    return entries.filter((e) => {
      if (outcome !== 'all' && (e.allowed ? 'allowed' : 'blocked') !== outcome) return false;
      if (scope !== 'all' && e.scope !== scope) return false;
      if (search.trim()) {
        const q = search.toLowerCase();
        return (
          e.purpose.toLowerCase().includes(q) ||
          e.destination.toLowerCase().includes(q) ||
          (e.reason ?? '').toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [entries, outcome, scope, search]);

  const counts = useMemo(
    () => ({
      allowed: entries.filter((e) => e.allowed).length,
      blocked: entries.filter((e) => !e.allowed).length,
    }),
    [entries]
  );

  const clearLog = async () => {
    await logService.clearNetworkAudit();
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Network"
          description="Every app-owned network request, allowed and blocked. Prompt bodies are never recorded."
          actions={
            <Button variant="outline" onClick={() => void clearLog()}>
              <Trash2 className="h-4 w-4" /> Clear log
            </Button>
          }
        />

        {/* Policy status */}
        <div className="mb-6 grid gap-3 sm:grid-cols-2">
          <div
            className={cn(
              'flex items-start gap-3 rounded-xl border p-4',
              settings.privacy.strictOffline
                ? 'border-brand bg-brand-soft dark:bg-brand/10'
                : 'border-border bg-card'
            )}
          >
            {settings.privacy.strictOffline ? (
              <ShieldCheck className="mt-0.5 h-5 w-5 text-brand-strong" />
            ) : (
              <Globe className="mt-0.5 h-5 w-5 text-muted-foreground" />
            )}
            <div>
              <p className="text-sm font-semibold">Strict Offline</p>
              <p className="mt-0.5 text-[13px] text-muted-foreground">
                {settings.privacy.strictOffline
                  ? 'On — internet access is blocked; loopback Ollama still works when allowed.'
                  : 'Off — app-owned features may use the network per their purpose.'}
              </p>
              <button
                className="mt-1.5 text-[12px] underline hover:text-foreground"
                onClick={() => router.navigate('/app/settings/privacy')}
              >
                Change in Settings → Privacy
              </button>
            </div>
          </div>
          <div className="rounded-xl border border-border bg-card p-4">
            <p className="text-sm font-semibold">Audit counters</p>
            <div className="mt-2 flex gap-4 text-[13px]">
              <span className="flex items-center gap-1.5">
                <ShieldCheck className="h-4 w-4 text-success" />
                {counts.allowed} allowed
              </span>
              <span className="flex items-center gap-1.5">
                <ShieldAlert className="h-4 w-4 text-destructive" />
                {counts.blocked} blocked
              </span>
            </div>
            <p className="mt-2 text-[11px] text-muted-foreground/70">
              Audit logging is {settings.privacy.auditNetwork ? 'on' : 'off'}.
            </p>
          </div>
        </div>

        {/* Filters */}
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <div className="relative">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Filter by purpose or destination"
              aria-label="Filter network log"
              className="w-64 rounded-lg border border-border bg-card py-1.5 pl-8 pr-3 text-[13px] outline-none focus:border-brand-strong"
            />
          </div>
          {(['all', 'allowed', 'blocked'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setOutcome(f)}
              aria-pressed={outcome === f}
              className={cn(
                'rounded-full border px-3 py-1 text-[12px] capitalize transition-colors',
                outcome === f
                  ? 'border-brand-strong bg-brand text-brand-foreground font-medium'
                  : 'border-border text-muted-foreground hover:text-foreground'
              )}
            >
              {f}
            </button>
          ))}
          <span className="mx-1 h-4 w-px bg-border" aria-hidden />
          {(['all', 'loopback', 'lan', 'internet'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setScope(f)}
              aria-pressed={scope === f}
              className={cn(
                'rounded-full border px-3 py-1 text-[12px] capitalize transition-colors',
                scope === f
                  ? 'border-foreground bg-muted font-medium'
                  : 'border-border text-muted-foreground hover:text-foreground'
              )}
            >
              {f}
            </button>
          ))}
        </div>

        {/* Log table */}
        <Section>
          {loading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="h-9 animate-pulse rounded-lg bg-muted" />
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <EmptyState
              icon={NetworkIcon}
              title={entries.length === 0 ? 'No network activity yet' : 'No entries match the filters'}
              description={
                entries.length === 0
                  ? 'Requests made by chats, downloads, searches and provider tests will appear here with their outcome.'
                  : 'Try clearing the filters above.'
              }
            />
          ) : (
            <ul className="divide-y divide-border text-[13px]">
              {filtered.slice(0, 200).map((e) => (
                <li key={e.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 py-2.5">
                  <time
                    className="w-16 shrink-0 font-mono text-[11px] text-muted-foreground/70 tabular-nums"
                    dateTime={new Date(e.ts).toISOString()}
                  >
                    {new Date(e.ts).toLocaleTimeString(undefined, { hour12: false })}
                  </time>
                  <span
                    className={cn(
                      'w-16 shrink-0 rounded-full px-2 py-0.5 text-center text-[10px] font-semibold uppercase',
                      e.allowed
                        ? 'bg-success/15 text-success'
                        : 'bg-destructive/15 text-destructive'
                    )}
                  >
                    {e.allowed ? 'Allowed' : 'Blocked'}
                  </span>
                  <span className="min-w-0 flex-1 truncate font-medium">{e.purpose}</span>
                  <span className="flex min-w-0 max-w-full items-center gap-1 text-muted-foreground">
                    {e.scope === 'loopback' ? (
                      <Home className="h-3 w-3 shrink-0" />
                    ) : e.scope === 'lan' ? (
                      <Wifi className="h-3 w-3 shrink-0" />
                    ) : (
                      <WifiOff className="hidden" aria-hidden />
                    )}
                    <span className="truncate font-mono text-[11px]">{e.destination}</span>
                  </span>
                  {!e.allowed && e.reason && (
                    <span className="w-full pl-[76px] text-[11px] text-muted-foreground/80 sm:w-auto sm:pl-0">
                      Reason: {e.reason}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Section>

        <p className="mt-4 text-center text-[11px] text-muted-foreground">
          Showing at most 200 entries · {filtered.length} of {entries.length} match
        </p>
      </div>
    </div>
  );
}
