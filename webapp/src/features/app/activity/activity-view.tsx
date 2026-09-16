'use client';

/**
 * ActivityView — local usage statistics + recent activity feed.
 * Everything is computed from local usage/day records; nothing is
 * uploaded anywhere.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  MessageSquare,
  FileText,
  Boxes,
  Brain,
  Trash2,
  MessageSquarePlus,
  Ban,
  Wrench,
  HardDrive,
  Download,
  DownloadCloud,
  Activity as ActivityIcon,
} from 'lucide-react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  CartesianGrid,
} from 'recharts';
import { logService } from '@/lib/services/log-service';
import { bus } from '@/lib/core/events/event-bus';
import { PageHeader, Section, EmptyState } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { cn, formatNumber, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { ActivityEntry, UsageDay } from '@/lib/types/domain';

const ACTIVITY_ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  'chat.created': MessageSquarePlus,
  'chat.deleted': Trash2,
  'generation.completed': MessageSquare,
  'generation.cancelled': Ban,
  'document.indexed': FileText,
  'model.downloaded': Download,
  'model.deleted': HardDrive,
  'memory.created': Brain,
  'memory.deleted': Brain,
  'backup.exported': DownloadCloud,
  'backup.imported': Boxes,
  'tool.executed': Wrench,
};

export function ActivityView() {
  const [usage, setUsage] = useState<UsageDay[]>([]);
  const [activity, setActivity] = useState<ActivityEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    const [u, a] = await Promise.all([
      logService.listUsage(),
      logService.listActivity(),
    ]);
    setUsage(u);
    setActivity(a);
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
    const unsubs = [
      bus.on('activity:changed', () => void load()),
      bus.on('usage:changed', () => void load()),
    ];
    return () => unsubs.forEach((u) => u());
  }, [load]);

  // Last 14 days, oldest → newest for the chart.
  const chartData = useMemo(() => {
    const byId = new Map(usage.map((d) => [d.id, d]));
    const days: Array<{ day: string; generations: number; label: string }> = [];
    for (let i = 13; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const id = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      const record = byId.get(id);
      days.push({
        day: d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
        generations: record?.generations ?? 0,
        label: id,
      });
    }
    return days;
  }, [usage]);

  const totals = useMemo(() => {
    const monthCutoff = Date.now() - 30 * 86_400_000;
    const month = usage.filter((d) => {
      const [y, m, day] = d.id.split('-').map(Number);
      return new Date(y, m - 1, day).getTime() >= monthCutoff;
    });
    return {
      generations: month.reduce((s, d) => s + d.generations, 0),
      cancellations: month.reduce((s, d) => s + d.cancellations, 0),
      tokensIn: month.reduce((s, d) => s + d.tokensIn, 0),
      tokensOut: month.reduce((s, d) => s + d.tokensOut, 0),
      chatsCreated: month.reduce((s, d) => s + d.chatsCreated, 0),
      documentsIndexed: month.reduce((s, d) => s + d.documentsIndexed, 0),
    };
  }, [usage]);

  const clearStats = async () => {
    await logService.clearUsage();
    toast({ title: 'Usage statistics cleared', description: 'Chats and messages were not touched.' });
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Activity"
          description="Local usage statistics. Nothing here ever leaves this device."
          actions={
            <Button variant="outline" onClick={() => void clearStats()}>
              <Trash2 className="h-4 w-4" /> Clear stats
            </Button>
          }
        />

        {/* Stat cards */}
        <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-3">
          <StatCard icon={MessageSquare} label="Generations · 30d" value={formatNumber(totals.generations)} />
          <StatCard icon={MessageSquarePlus} label="New chats · 30d" value={formatNumber(totals.chatsCreated)} />
          <StatCard icon={FileText} label="Docs indexed · 30d" value={formatNumber(totals.documentsIndexed)} />
          <StatCard icon={ActivityIcon} label="Tokens out · 30d" value={`~${formatNumber(totals.tokensOut)}`} />
          <StatCard icon={Ban} label="Stopped · 30d" value={formatNumber(totals.cancellations)} />
          <StatCard icon={Brain} label="Memories" value={formatNumber(activity.filter((a) => a.type === 'memory.created').length)} />
        </div>

        {/* Chart */}
        <Section title="Generations per day" description="Last 14 days, from local usage records.">
          <div className="h-56 w-full" role="img" aria-label="Bar chart of generations per day over the last 14 days">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 4, right: 4, bottom: 0, left: -22 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                <XAxis
                  dataKey="day"
                  tick={{ fontSize: 10, fill: 'var(--muted-foreground)' }}
                  interval="preserveStartEnd"
                  tickLine={false}
                  axisLine={{ stroke: 'var(--border)' }}
                />
                <YAxis
                  allowDecimals={false}
                  tick={{ fontSize: 10, fill: 'var(--muted-foreground)' }}
                  tickLine={false}
                  axisLine={false}
                />
                <RechartsTooltip
                  cursor={{ fill: 'var(--muted)', opacity: 0.4 }}
                  contentStyle={{
                    background: 'var(--popover)',
                    border: '1px solid var(--border)',
                    borderRadius: 10,
                    fontSize: 12,
                    color: 'var(--popover-foreground)',
                  }}
                />
                <Bar dataKey="generations" fill="var(--brand-strong)" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Section>

        {/* Recent activity */}
        <Section title="Recent activity">
          {loading ? (
            <div className="space-y-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="h-10 animate-pulse rounded-lg bg-muted" />
              ))}
            </div>
          ) : activity.length === 0 ? (
            <EmptyState
              icon={ActivityIcon}
              title="No activity yet"
              description="Generations, imports and tool runs will appear here."
            />
          ) : (
            <ul className="max-h-96 space-y-1 overflow-y-auto scrollbar-slim">
              {activity.slice(0, 50).map((entry) => {
                const Icon = ACTIVITY_ICONS[entry.type] ?? ActivityIcon;
                return (
                  <li
                    key={entry.id}
                    className="flex items-center gap-3 rounded-lg px-2 py-2 text-[13px] hover:bg-muted/50"
                  >
                    <span className="rounded-lg bg-muted p-1.5">
                      <Icon className="h-3.5 w-3.5 text-muted-foreground" />
                    </span>
                    <span className="min-w-0 flex-1 truncate">{entry.label}</span>
                    <time className="shrink-0 text-[11px] text-muted-foreground/70" dateTime={new Date(entry.ts).toISOString()}>
                      {formatRelativeTime(entry.ts)}
                    </time>
                  </li>
                );
              })}
            </ul>
          )}
        </Section>
      </div>
    </div>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
}) {
  return (
    <div className={cn('rounded-xl border border-border bg-card p-4')}>
      <div className="flex items-center gap-2 text-muted-foreground">
        <Icon className="h-3.5 w-3.5" />
        <span className="text-[11px] font-medium uppercase tracking-wide">{label}</span>
      </div>
      <p className="mt-1.5 font-display text-2xl font-semibold tabular-nums">{value}</p>
    </div>
  );
}
