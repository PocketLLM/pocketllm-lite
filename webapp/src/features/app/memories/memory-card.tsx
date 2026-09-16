'use client';

/**
 * MemoryCard — one remembered fact.
 *
 * Shows the fact, subject/type/confidence metadata, usage recency and
 * the per-card actions (pin, enable, edit, delete). Superseded
 * memories render dimmed with a note pointing at their replacement.
 */
import { Pencil, Pin, PinOff, Power, Trash2 } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { MetaPill } from '@/features/app/shared/ui';
import { cn, formatRelativeTime } from '@/lib/utils';
import type { Memory } from '@/lib/types/domain';

const TYPE_LABEL: Record<Memory['type'], string> = {
  fact: 'Fact',
  preference: 'Preference',
  instruction: 'Instruction',
  context: 'Context',
};

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/** Small horizontal confidence bar with a percentage label. */
function ConfidenceBar({ value }: { value: number }) {
  const pct = Math.round(Math.max(0, Math.min(1, value)) * 100);
  return (
    <span className="inline-flex items-center gap-1.5" title={`confidence ${pct}%`}>
      <span className="text-[11px] text-muted-foreground">confidence</span>
      <span
        className="block h-1 w-14 overflow-hidden rounded-full bg-muted"
        role="img"
        aria-label={`${pct}% confidence`}
      >
        <span
          className="block h-full rounded-full bg-brand-strong"
          style={{ width: `${pct}%` }}
        />
      </span>
      <span className="text-[11px] tabular-nums text-muted-foreground">{pct}%</span>
    </span>
  );
}

export function MemoryCard({
  memory,
  supersederFact,
  onTogglePin,
  onToggleEnabled,
  onEdit,
  onDelete,
}: {
  memory: Memory;
  /** Fact text of the memory that superseded this one, when known. */
  supersederFact?: string;
  onTogglePin: (memory: Memory) => void;
  onToggleEnabled: (memory: Memory) => void;
  onEdit: (memory: Memory) => void;
  onDelete: (memory: Memory) => void;
}) {
  const superseded = Boolean(memory.supersededBy);
  const factLabel = truncate(memory.fact, 48);

  return (
    <li
      className={cn(
        'rounded-xl border border-border bg-card p-4 transition-opacity',
        superseded && 'opacity-60'
      )}
    >
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 flex-1">
          <p className="text-sm leading-relaxed">{memory.fact}</p>

          <div className="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1.5 text-[11px] text-muted-foreground">
            {memory.pinned && <MetaPill tone="accent">Pinned</MetaPill>}
            {memory.subject && memory.subject !== 'general' && (
              <MetaPill>{memory.subject}</MetaPill>
            )}
            <Badge variant="outline" className="px-1.5 py-0 text-[11px] font-medium">
              {TYPE_LABEL[memory.type]}
            </Badge>
            {!memory.enabled && (
              <Badge variant="secondary" className="px-1.5 py-0 text-[11px] font-medium">
                Disabled
              </Badge>
            )}
            {superseded && (
              <Badge variant="secondary" className="px-1.5 py-0 text-[11px] font-medium">
                Superseded
              </Badge>
            )}
            <ConfidenceBar value={memory.confidence} />
            <span>created {formatRelativeTime(memory.createdAt)}</span>
            {memory.updatedAt > memory.createdAt + 2_000 && (
              <span>updated {formatRelativeTime(memory.updatedAt)}</span>
            )}
            <span>
              {memory.lastUsedAt
                ? `used ${formatRelativeTime(memory.lastUsedAt)}`
                : 'never used'}
            </span>
          </div>

          {superseded && (
            <p className="mt-2 text-xs text-muted-foreground">
              {supersederFact
                ? `Replaced by a newer memory: “${truncate(supersederFact, 90)}”`
                : 'A newer memory replaced this one.'}
            </p>
          )}
        </div>

        <div className="flex shrink-0 items-center gap-0.5 self-start">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => onTogglePin(memory)}
            aria-label={`${memory.pinned ? 'Unpin' : 'Pin'} memory: ${factLabel}`}
            title={memory.pinned ? 'Unpin memory' : 'Pin memory'}
          >
            {memory.pinned ? (
              <PinOff aria-hidden />
            ) : (
              <Pin aria-hidden className="text-muted-foreground" />
            )}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => onToggleEnabled(memory)}
            aria-label={`${memory.enabled ? 'Disable' : 'Enable'} memory: ${factLabel}`}
            title={memory.enabled ? 'Disable memory' : 'Enable memory'}
          >
            <Power
              aria-hidden
              className={memory.enabled ? 'text-foreground' : 'text-muted-foreground'}
            />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => onEdit(memory)}
            aria-label={`Edit memory: ${factLabel}`}
            title="Edit memory"
          >
            <Pencil aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="text-muted-foreground hover:text-destructive"
            onClick={() => onDelete(memory)}
            aria-label={`Delete memory: ${factLabel}`}
            title="Delete memory"
          >
            <Trash2 aria-hidden />
          </Button>
        </div>
      </div>
    </li>
  );
}
