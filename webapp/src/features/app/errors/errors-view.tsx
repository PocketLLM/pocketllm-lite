'use client';

/**
 * ErrorsView — structured local error log.
 * Safe messages only: never prompt bodies, documents, API keys or
 * memory facts. Bounded to keep storage sane.
 */
import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, Trash2, ChevronDown, BugOff } from 'lucide-react';
import { logService } from '@/lib/services/log-service';
import { bus } from '@/lib/core/events/event-bus';
import { PageHeader, Section, EmptyState } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { cn, formatRelativeTime } from '@/lib/utils';

export function ErrorsView() {
  const [entries, setEntries] = useState<Awaited<ReturnType<typeof logService.listErrors>>>([]);
  const [open, setOpen] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setEntries(await logService.listErrors());
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
    return bus.on('errors:changed', () => void load());
  }, [load]);

  const clear = async () => {
    await logService.clearErrors();
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Errors"
          description="Structured error records — feature, code, safe message and version. Deleting logs never deletes chat data."
          actions={
            <Button variant="outline" onClick={() => void clear()}>
              <Trash2 className="h-4 w-4" /> Clear errors
            </Button>
          }
        />

        <Section>
          {loading ? (
            <div className="space-y-2">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="h-12 animate-pulse rounded-lg bg-muted" />
              ))}
            </div>
          ) : entries.length === 0 ? (
            <EmptyState
              icon={BugOff}
              title="No errors recorded"
              description="When something fails, the safe error details appear here for diagnosis."
            />
          ) : (
            <ul className="space-y-2">
              {entries.slice(0, 100).map((e) => {
                const expanded = open === e.id;
                return (
                  <li
                    key={e.id}
                    className={cn(
                      'rounded-xl border p-3 text-[13px]',
                      expanded ? 'border-destructive/40 bg-destructive/5' : 'border-border bg-card'
                    )}
                  >
                    <button
                      className="flex w-full items-center gap-2 text-left"
                      onClick={() => setOpen(expanded ? null : e.id)}
                      aria-expanded={expanded}
                      aria-label={`Error details: ${e.message.slice(0, 40)}`}
                    >
                      <AlertCircle className="h-4 w-4 shrink-0 text-destructive" />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-medium">{e.message}</span>
                        <span className="text-[11px] text-muted-foreground">
                          {e.feature} · {e.code} · {formatRelativeTime(e.ts)} · v{e.appVersion}
                        </span>
                      </span>
                      <ChevronDown
                        className={cn(
                          'h-4 w-4 shrink-0 text-muted-foreground transition-transform',
                          expanded && 'rotate-180'
                        )}
                      />
                    </button>
                    {expanded && e.stack && (
                      <pre className="mt-2 max-h-48 overflow-auto rounded-lg bg-background p-2 font-mono text-[11px] leading-relaxed scrollbar-slim">
                        {e.stack}
                      </pre>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </Section>

        <p className="mt-4 text-center text-[11px] text-muted-foreground">
          Error records contain no prompt bodies, documents, keys or memory facts.
        </p>
      </div>
    </div>
  );
}
