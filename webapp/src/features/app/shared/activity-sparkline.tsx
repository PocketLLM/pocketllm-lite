'use client';

/**
 * ActivitySparkline — shared 14-day message-activity chart.
 *
 * Extracted from the chat inspector (round 6) so the History view can
 * render the same visual across ALL conversations. One bar per local
 * midnight-aligned day; empty days render as honest 20%-opacity ticks;
 * today uses the strong brand fill. Native <title> tooltips keep every
 * bar accessible without JavaScript hover handling.
 */
import { cn } from '@/lib/utils';

/** One day bucket in the activity window. */
export interface ActivityDay {
  /** Human label, e.g. "Sep 15". */
  label: string;
  /** Weekday short label, e.g. "Mon". */
  weekday: string;
  /** Local-midnight timestamp of the bucket. */
  ts: number;
  /** Messages that day. */
  count: number;
  /** Whether this bucket is today. */
  isToday: boolean;
}

export interface ActivityWindow {
  days: ActivityDay[];
  /** Total messages inside the window. */
  inWindow: number;
  /** Max per-day count (>= 1) used for bar scaling. */
  max: number;
  /** Busiest day bucket. */
  busiest: ActivityDay;
}

const DAY_MS = 86_400_000;

/** Local midnight of a timestamp (start of its day). */
function midnight(ts: number): number {
  const d = new Date(ts);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

/**
 * Buckets timestamps into the last `windowDays` local-midnight-aligned
 * days. Anything older than the window is ignored (it still counts
 * toward nothing — the strip is honest about being a 14-day view).
 */
export function computeActivityWindow(
  timestamps: number[],
  windowDays = 14
): ActivityWindow {
  const today = midnight(Date.now());
  const days: ActivityDay[] = [];
  for (let i = windowDays - 1; i >= 0; i--) {
    const ts = today - i * DAY_MS;
    const d = new Date(ts);
    days.push({
      label: d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
      weekday: d.toLocaleDateString(undefined, { weekday: 'short' }),
      ts,
      count: 0,
      isToday: i === 0,
    });
  }
  const indexByTs = new Map(days.map((d, i) => [d.ts, i]));
  for (const ts of timestamps) {
    const idx = indexByTs.get(midnight(ts));
    if (idx != null) days[idx].count += 1;
  }
  const inWindow = days.reduce((sum, d) => sum + d.count, 0);
  const max = Math.max(1, ...days.map((d) => d.count));
  const busiest = days.reduce((a, b) => (b.count > a.count ? b : a), days[0]);
  return { days, inWindow, max, busiest };
}

/**
 * The sparkline itself.
 *
 * `height` is the bar area height in viewBox units; the SVG viewBox is
 * computed so the last bar always keeps `padRight` units of breathing
 * room (a VLM round-6 fix — clipped edges read as a rendering bug).
 */
export function ActivitySparkline({
  window: activity,
  ariaContext,
  compact = false,
  className,
}: {
  window: ActivityWindow;
  /** Extra words appended to the aria-label describing scope, e.g. "in this conversation". */
  ariaContext?: string;
  /** Compact variant — shorter bars for dense layouts like list headers. */
  compact?: boolean;
  className?: string;
}) {
  const barW = compact ? 10 : 12;
  const gap = compact ? 15 : 18;
  const h = compact ? 24 : 36;
  const baseY = compact ? 28 : 40;
  const svgH = compact ? 32 : 44;
  const padRight = 4;
  const viewW = activity.days.length * gap + padRight;

  return (
    <svg
      viewBox={`0 0 ${viewW} ${svgH}`}
      className={cn('w-full', className)}
      role="img"
      aria-label={`Message activity over the last ${activity.days.length} days${ariaContext ? ` ${ariaContext}` : ''}: ${activity.inWindow} messages, busiest day ${activity.busiest.label} with ${activity.busiest.count}.`}
    >
      {activity.days.map((d, i) => {
        const barH = d.count === 0 ? 2 : Math.max(3, (d.count / activity.max) * h);
        return (
          <rect
            key={d.ts}
            x={i * gap}
            y={baseY - barH}
            width={barW}
            height={barH}
            rx={2}
            className={cn(
              'cursor-default transition-opacity duration-200',
              d.isToday ? 'fill-brand-strong' : 'fill-brand',
              d.count === 0 ? 'opacity-20' : 'opacity-55 hover:opacity-100'
            )}
          >
            <title>
              {d.weekday} {d.label} — {d.count} message{d.count === 1 ? '' : 's'}
              {d.isToday ? ' (today)' : ''}
            </title>
          </rect>
        );
      })}
    </svg>
  );
}

/**
 * ActivityStrip — a compact "last 14 days" summary card: label, total,
 * sparkline and date-range footnote. Used under the History page header
 * to visualize ALL conversations at once.
 */
export function ActivityStrip({
  window: activity,
  scopeLabel,
}: {
  window: ActivityWindow;
  /** e.g. "across 6 conversations". */
  scopeLabel: string;
}) {
  if (activity.inWindow === 0) return null;
  return (
    <div className="mb-5 mt-4 flex items-center gap-4 rounded-xl border border-border bg-card px-4 py-3">
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-3">
          <span className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground">
            Last {activity.days.length} days
          </span>
          <span className="font-mono text-[12px] tabular-nums">
            {activity.inWindow} message{activity.inWindow === 1 ? '' : 's'}
          </span>
        </div>
        <ActivitySparkline window={activity} compact ariaContext={scopeLabel} className="mt-1.5" />
        <div className="mt-0.5 flex items-center justify-between text-[9.5px] text-muted-foreground/80">
          <span>{activity.days[0].label}</span>
          <span className="flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-sm bg-brand-strong" aria-hidden />
            today
          </span>
          <span>{activity.days[activity.days.length - 1].label}</span>
        </div>
      </div>
    </div>
  );
}
