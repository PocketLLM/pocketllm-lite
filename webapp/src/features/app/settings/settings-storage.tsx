'use client';

/**
 * Data & Storage — storage estimate, per-category usage, log
 * retention, log cleanup, and the reset danger zone (type-to-confirm).
 */
import { useCallback, useEffect, useState } from 'react';
import { Loader2, RefreshCw, TriangleAlert } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Progress } from '@/components/ui/progress';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Section, StatusDot } from '@/features/app/shared/ui';
import { SettingRow, SettingRows } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { backupService } from '@/lib/services/backup-service';
import { logService } from '@/lib/services/log-service';
import { modelService } from '@/lib/services/model-service';
import { capabilityProbe, type Capabilities } from '@/lib/core/net/capabilities';
import {
  chatRepo,
  chunkRepo,
  documentRepo,
  memoryRepo,
  messageRepo,
  noteRepo,
  promptRepo,
  skillRepo,
} from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { toast } from '@/hooks/use-toast';
import { formatBytes, formatNumber } from '@/lib/utils';

/* ------------------------------ types ------------------------------- */

type ResetCategory =
  | 'chats'
  | 'models'
  | 'documents'
  | 'memories'
  | 'settings'
  | 'everything';

type CleanKey = 'network' | 'errors' | 'usage';

interface UsageRow {
  key: string;
  label: string;
  value: string;
}

const RESET_INFO: Record<
  ResetCategory,
  { title: string; detail: string }
> = {
  chats: {
    title: 'Chats',
    detail: 'All conversations, messages, branches and tool events.',
  },
  models: {
    title: 'Models',
    detail: 'Downloaded model files and download tasks.',
  },
  documents: {
    title: 'Documents',
    detail: 'Sources, chunks and embeddings.',
  },
  memories: {
    title: 'Memories',
    detail: 'Extracted facts about you.',
  },
  settings: {
    title: 'Settings',
    detail: 'Every preference back to its default.',
  },
  everything: {
    title: 'Everything',
    detail:
      'All of the above, plus personas, prompts, skills, tags, notes, transcripts, lab runs and all logs.',
  },
};

const CLEAN_INFO: Record<
  CleanKey,
  { title: string; run: () => Promise<void>; done: string }
> = {
  network: {
    title: 'Clear network log',
    run: () => logService.clearNetworkAudit(),
    done: 'Network audit log cleared.',
  },
  errors: {
    title: 'Clear error log',
    run: () => logService.clearErrors(),
    done: 'Error log cleared.',
  },
  usage: {
    title: 'Clear usage stats',
    run: () => logService.clearUsage(),
    done: 'Usage statistics cleared.',
  },
};

/** Bus events to re-emit per reset category, so every view refreshes. */
function emitResetEvents(category: ResetCategory): void {
  const emitVoid = (events: string[]) => {
    for (const e of events) bus.emit(e as 'chats:changed');
  };
  const emitDocsAndMessages = () => {
    bus.emit('documents:changed', {});
    bus.emit('messages:changed', { chatId: '' });
  };
  switch (category) {
    case 'chats':
      emitVoid(['chats:changed', 'toolEvents:changed']);
      bus.emit('messages:changed', { chatId: '' });
      break;
    case 'models':
      emitVoid(['models:changed', 'downloads:changed']);
      break;
    case 'documents':
      emitDocsAndMessages();
      break;
    case 'memories':
      emitVoid(['memories:changed']);
      break;
    case 'settings':
      emitVoid(['settings:changed']);
      break;
    case 'everything':
      emitVoid([
        'chats:changed',
        'toolEvents:changed',
        'memories:changed',
        'notes:changed',
        'prompts:changed',
        'skills:changed',
        'personas:changed',
        'tags:changed',
        'transcripts:changed',
        'labRuns:changed',
        'models:changed',
        'downloads:changed',
        'settings:changed',
      ]);
      emitDocsAndMessages();
      break;
  }
}

/* ------------------------------ view ------------------------------- */

export function StorageSettings() {
  const retention = useAppStore((s) => s.settings.storage.logRetentionDays);
  const patchSettings = useAppStore((s) => s.patchSettings);

  const [caps, setCaps] = useState<Capabilities | null>(null);
  const [usageRows, setUsageRows] = useState<UsageRow[] | null>(null);
  const [usageError, setUsageError] = useState<string | null>(null);
  const [persisting, setPersisting] = useState(false);

  const [cleanTarget, setCleanTarget] = useState<CleanKey | null>(null);
  const [cleaning, setCleaning] = useState(false);

  const [resetCategory, setResetCategory] = useState<ResetCategory>('chats');
  const [confirmText, setConfirmText] = useState('');
  const [resetting, setResetting] = useState(false);

  const loadUsage = useCallback(async () => {
    setUsageError(null);
    try {
      const [models, docs, chunks, chats, messages, memories, notes, prompts, skills] =
        await Promise.all([
          modelService.storageUsage(),
          documentRepo.getAll(),
          chunkRepo.count(),
          chatRepo.count(),
          messageRepo.count(),
          memoryRepo.count(),
          noteRepo.count(),
          promptRepo.count(),
          skillRepo.count(),
        ]);
      const docBytes = docs.reduce((s, d) => s + (d.sizeBytes ?? 0), 0);
      const docIndex = docs.reduce((s, d) => s + (d.indexSizeBytes ?? 0), 0);
      setUsageRows([
        {
          key: 'models',
          label: 'Models',
          value: `${formatNumber(models.count)} · ${formatBytes(models.modelsBytes)}`,
        },
        {
          key: 'documents',
          label: 'Documents',
          value: `${formatNumber(docs.length)} · ${formatBytes(docBytes)} sources · ${formatNumber(chunks)} chunks (${formatBytes(docIndex)} index)`,
        },
        { key: 'chats', label: 'Chats', value: formatNumber(chats) },
        { key: 'messages', label: 'Messages', value: formatNumber(messages) },
        { key: 'memories', label: 'Memories', value: formatNumber(memories) },
        { key: 'notes', label: 'Notes', value: formatNumber(notes) },
        { key: 'prompts', label: 'Prompts', value: formatNumber(prompts) },
        { key: 'skills', label: 'Skills', value: formatNumber(skills) },
      ]);
    } catch (err) {
      console.error('[storage] usage load failed', err);
      setUsageError(err instanceof Error ? err.message : String(err));
      setUsageRows([]);
    }
  }, []);

  useEffect(() => {
    void capabilityProbe.scan().then(setCaps).catch(() => setCaps(null));
    void loadUsage();
  }, [loadUsage]);

  const quota = caps?.storageQuota ?? null;
  const percent =
    quota && quota.quota > 0 ? Math.min(100, (quota.usage / quota.quota) * 100) : null;

  const requestPersistence = async () => {
    setPersisting(true);
    try {
      const granted = await capabilityProbe.requestPersistence();
      setCaps((c) => (c ? { ...c, storagePersisted: granted } : c));
      toast({
        title: granted ? 'Persistent storage granted' : 'Not granted',
        description: granted
          ? 'The browser will avoid evicting PocketLLM data under storage pressure.'
          : 'This browser declined. Data stays best-effort — export backups if it matters.',
        variant: granted ? undefined : 'destructive',
      });
    } catch (err) {
      toast({
        title: 'Persistence request failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setPersisting(false);
    }
  };

  const runClean = async () => {
    if (!cleanTarget) return;
    const target = cleanTarget;
    setCleaning(true);
    try {
      await CLEAN_INFO[target].run();
      toast({ title: CLEAN_INFO[target].done });
    } catch (err) {
      toast({
        title: 'Cleanup failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setCleaning(false);
      setCleanTarget(null);
    }
  };

  const runReset = async () => {
    setResetting(true);
    try {
      await backupService.reset(resetCategory);
      emitResetEvents(resetCategory);
      toast({
        title: `${RESET_INFO[resetCategory].title} reset`,
        description: 'Deleted from this browser. This cannot be undone.',
      });
      setConfirmText('');
      await loadUsage();
      const fresh = await capabilityProbe.scan().catch(() => null);
      if (fresh) setCaps(fresh);
    } catch (err) {
      toast({
        title: 'Reset failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setResetting(false);
    }
  };

  const canReset = confirmText.trim() === 'RESET' && !resetting;

  return (
    <div className="space-y-6">
      {/* ------------------------- storage estimate ------------------------ */}
      <Section
        title="Storage"
        description="What this browser reports for the app's origin (IndexedDB + OPFS + caches)."
      >
        {caps === null ? (
          <div className="space-y-2">
            <Skeleton className="h-4 w-40" />
            <Skeleton className="h-2 w-full" />
            <Skeleton className="h-4 w-64" />
          </div>
        ) : (
          <div className="space-y-3">
            {quota ? (
              <>
                <Progress
                  value={Math.max(percent ?? 0, quota.usage > 0 ? 2 : 0)}
                  aria-label="Storage used"
                />
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="text-[13px]">
                    <span className="font-medium">{formatBytes(quota.usage)}</span>{' '}
                    <span className="text-muted-foreground">
                      of {formatBytes(quota.quota)} used
                      {percent !== null && ` (${percent.toFixed(1)}%)`}
                    </span>
                  </p>
                  <StatusDot tone={caps.storagePersisted ? 'success' : 'warning'}>
                    {caps.storagePersisted
                      ? 'Persistent storage granted'
                      : 'Best-effort storage — browser may evict'}
                  </StatusDot>
                </div>
              </>
            ) : (
              <p className="text-[13px] text-muted-foreground">
                This browser does not report a storage estimate.
              </p>
            )}
            <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
              <p className="max-w-md text-xs leading-relaxed text-muted-foreground">
                Browsers may evict storage under pressure. Export a backup if
                this data matters.
              </p>
              <Button
                variant="outline"
                size="sm"
                onClick={() => void requestPersistence()}
                disabled={persisting || caps.storagePersisted}
              >
                {persisting ? (
                  <Loader2 className="animate-spin" aria-hidden />
                ) : null}
                {caps.storagePersisted ? 'Already persistent' : 'Request persistent storage'}
              </Button>
            </div>
          </div>
        )}
      </Section>

      {/* ------------------------- category usage ------------------------- */}
      <Section
        title="What's stored"
        description="Row counts and sizes from this browser's databases."
      >
        <div className="mb-2 flex justify-end">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => void loadUsage()}
            aria-label="Refresh usage"
          >
            <RefreshCw aria-hidden />
          </Button>
        </div>
        {usageError ? (
          <p className="text-[13px] text-destructive" role="alert">
            Could not read usage: {usageError}
          </p>
        ) : usageRows === null ? (
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="h-6 w-full" />
            ))}
          </div>
        ) : (
          <dl className="divide-y divide-border">
            {usageRows.map((row) => (
              <div
                key={row.key}
                className="flex items-center justify-between gap-4 py-2"
              >
                <dt className="text-[13px] font-medium">{row.label}</dt>
                <dd className="text-right font-mono text-xs text-muted-foreground">
                  {row.value}
                </dd>
              </div>
            ))}
          </dl>
        )}
      </Section>

      {/* --------------------------- log retention ------------------------- */}
      <Section
        title="Logs"
        description="Activity, network audit and error rows older than this are pruned on startup."
      >
        <SettingRows>
          <SettingRow
            label="Log retention"
            description="Usage statistics are kept regardless — they're a single row per day."
            htmlFor="setting-retention"
            control={
              <Select
                value={String(retention)}
                onValueChange={(v) =>
                  patchSettings({ storage: { logRetentionDays: Number(v) } })
                }
              >
                <SelectTrigger
                  id="setting-retention"
                  aria-label="Log retention"
                  className="w-full sm:w-[160px]"
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="7">7 days</SelectItem>
                  <SelectItem value="30">30 days</SelectItem>
                  <SelectItem value="90">90 days</SelectItem>
                  <SelectItem value="0">Forever</SelectItem>
                </SelectContent>
              </Select>
            }
          />
        </SettingRows>

        <div className="mt-4 flex flex-wrap gap-2">
          {(Object.keys(CLEAN_INFO) as CleanKey[]).map((key) => (
            <Button
              key={key}
              variant="outline"
              size="sm"
              onClick={() => setCleanTarget(key)}
            >
              {CLEAN_INFO[key].title}
            </Button>
          ))}
        </div>
      </Section>

      {/* ---------------------------- danger zone ------------------------- */}
      <Section
        className="border-destructive/50"
        title="Danger zone"
        description="Resets delete data in this browser permanently. Export a backup first — there is no undo and no recycle bin."
      >
        <SettingRows>
          <SettingRow
            danger
            label="Reset"
            description={RESET_INFO[resetCategory].detail}
            htmlFor="setting-reset-category"
            control={
              <Select
                value={resetCategory}
                onValueChange={(v) => {
                  setResetCategory(v as ResetCategory);
                  setConfirmText('');
                }}
              >
                <SelectTrigger
                  id="setting-reset-category"
                  aria-label="Reset category"
                  className="w-full sm:w-[180px] border-destructive/40"
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {(Object.keys(RESET_INFO) as ResetCategory[]).map((c) => (
                    <SelectItem key={c} value={c}>
                      {RESET_INFO[c].title}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            }
          />
          <SettingRow
            danger
            label="Type RESET to confirm"
            description={`Deletes: ${RESET_INFO[resetCategory].detail}`}
            htmlFor="setting-reset-confirm"
            control={
              <div className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:items-center">
                <Input
                  id="setting-reset-confirm"
                  value={confirmText}
                  onChange={(e) => setConfirmText(e.target.value)}
                  placeholder="RESET"
                  aria-label="Type RESET to confirm"
                  autoComplete="off"
                  spellCheck={false}
                  className="w-full font-mono uppercase sm:w-28"
                />
                <Button
                  variant="destructive"
                  disabled={!canReset}
                  onClick={() => void runReset()}
                >
                  {resetting ? (
                    <Loader2 className="animate-spin" aria-hidden />
                  ) : null}
                  Delete {RESET_INFO[resetCategory].title.toLowerCase()}
                </Button>
              </div>
            }
          />
        </SettingRows>
        <div className="mt-4 flex gap-2.5 rounded-xl border border-destructive/30 bg-destructive/5 p-3">
          <TriangleAlert
            className="mt-0.5 h-4 w-4 shrink-0 text-destructive"
            aria-hidden
          />
          <p className="text-xs leading-relaxed text-muted-foreground">
            Model downloads can be large — resetting Models frees their bytes
            immediately. Settings reset keeps your data and only restores
            defaults.
          </p>
        </div>
      </Section>

      {/* --------------------------- clean confirms ------------------------ */}
      <AlertDialog
        open={cleanTarget !== null}
        onOpenChange={(open) => !open && !cleaning && setCleanTarget(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {cleanTarget ? CLEAN_INFO[cleanTarget].title : ''}
            </AlertDialogTitle>
            <AlertDialogDescription>
              This permanently deletes the log rows from this browser. It does
              not touch chats, documents or any other data.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep it</AlertDialogCancel>
            <AlertDialogAction
              onClick={(e) => {
                e.preventDefault(); // stay open until the async work settles
                void runClean();
              }}
            >
              {cleaning ? <Loader2 className="animate-spin" aria-hidden /> : null}
              Clear log
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
