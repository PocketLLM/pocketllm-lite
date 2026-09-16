'use client';

/**
 * ModelsView — model manager.
 *
 * Shows honest browser capabilities, installed model manifests
 * (real bytes in OPFS) and the curated browser-model catalog with a
 * live, resumable download state machine. Capability claims are never
 * guessed — unknown stays unknown.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Cpu,
  Download,
  HardDrive,
  Package,
  Pause,
  Play,
  Search,
  Trash2,
  Upload,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
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
import { EmptyState, MetaPill, PageHeader, Section, StatusDot } from '@/features/app/shared/ui';
import { modelService } from '@/lib/services/model-service';
import { capabilityProbe, type Capabilities } from '@/lib/core/net/capabilities';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { cn, formatBytes, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type {
  DownloadState,
  DownloadTask,
  ModelCatalogEntry,
  ModelManifest,
} from '@/lib/types/domain';

/* ------------------------------ helpers ------------------------------ */

const ACTIVE_STATES: DownloadState[] = [
  'queued',
  'downloading',
  'paused',
  'verifying',
  'installing',
];

const STATE_LABELS: Record<DownloadState, string> = {
  queued: 'Queued',
  downloading: 'Downloading',
  paused: 'Paused',
  verifying: 'Verifying checksum',
  installing: 'Installing',
  ready: 'Ready',
  failed: 'Failed',
  cancelled: 'Cancelled',
};

/** The most relevant download for a catalog entry (active first). */
function pickTask(
  tasks: DownloadTask[],
  catalogId: string
): DownloadTask | undefined {
  const mine = tasks
    .filter((t) => t.modelCatalogId === catalogId)
    .sort((a, b) => b.updatedAt - a.updatedAt);
  return mine.find((t) => ACTIVE_STATES.includes(t.state)) ?? mine[0];
}

function tierBadge(tier: ModelCatalogEntry['tier']) {
  if (tier === 'tiny')
    return <MetaPill tone="outline">tiny</MetaPill>;
  if (tier === 'small')
    return <MetaPill tone="accent">small</MetaPill>;
  return (
    <span className="inline-flex items-center rounded-full bg-foreground px-2 py-0.5 text-[11px] font-medium text-background">
      medium
    </span>
  );
}

function formatContext(limit: number | null): string {
  if (!limit) return 'unknown context';
  if (limit >= 1024) return `${Math.round(limit / 1024)}K context`;
  return `${limit} context`;
}

/* --------------------------- capability chips -------------------------- */

function CapChip({
  label,
  ok,
  hint,
}: {
  label: string;
  ok: boolean;
  hint?: string;
}) {
  return (
    <span
      title={hint}
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs',
        ok
          ? 'border-success/40 bg-success/10 text-success'
          : 'border-border bg-muted text-muted-foreground'
      )}
    >
      {ok ? (
        <CheckCircle2 className="h-3.5 w-3.5" aria-hidden />
      ) : (
        <CircleAlert className="h-3.5 w-3.5" aria-hidden />
      )}
      {label}
    </span>
  );
}

function capabilityHeadline(caps: Capabilities): string {
  if (!caps.opfs) {
    return 'This browser cannot store model downloads (no private file system), so browser models are unavailable here.';
  }
  if (caps.webgpu) {
    return 'This browser can run small GGUF models — WebGPU acceleration is available.';
  }
  if (caps.wasmSimd) {
    return 'This browser can run tiny GGUF models on CPU (WASM SIMD). Large models are not recommended.';
  }
  return 'This browser cannot run GGUF models locally — no WebGPU and no WASM SIMD.';
}

/* ------------------------------ main view ----------------------------- */

export function ModelsView() {
  const [caps, setCaps] = useState<Capabilities | null>(null);
  const [manifests, setManifests] = useState<ModelManifest[] | null>(null);
  const [downloads, setDownloads] = useState<DownloadTask[]>([]);
  const [deleting, setDeleting] = useState<ModelManifest | null>(null);
  const [confirmingEntry, setConfirmingEntry] = useState<ModelCatalogEntry | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [importing, setImporting] = useState(false);

  const catalog = useMemo(() => modelService.catalog(), []);

  const refreshInstalled = useCallback(async () => {
    try {
      setManifests(await modelService.installed());
    } catch (err) {
      console.error('[models] failed to load manifests', err);
      setManifests([]);
    }
  }, []);

  const refreshDownloads = useCallback(async () => {
    try {
      setDownloads(await modelService.listDownloads());
    } catch (err) {
      console.error('[models] failed to load downloads', err);
    }
  }, []);

  useEffect(() => {
    void capabilityProbe.scan().then(setCaps);
    void refreshInstalled();
    void refreshDownloads();
    const un1 = bus.on('models:changed', () => void refreshInstalled());
    const un2 = bus.on('downloads:changed', () => void refreshDownloads());
    return () => {
      un1();
      un2();
    };
  }, [refreshInstalled, refreshDownloads]);

  // Active-download polling (belt-and-braces alongside bus events).
  const hasActive = downloads.some((d) =>
    ['queued', 'downloading', 'verifying', 'installing'].includes(d.state)
  );
  useEffect(() => {
    if (!hasActive) return;
    const t = setInterval(() => void refreshDownloads(), 500);
    return () => clearInterval(t);
  }, [hasActive, refreshDownloads]);

  /* ----------------------------- actions ----------------------------- */

  const startDownload = useCallback(async (entry: ModelCatalogEntry) => {
    try {
      await modelService.startDownload(entry.id);
      await refreshDownloads();
      toast({
        title: 'Download started',
        description: `${entry.name} · ${formatBytes(entry.sizeBytes)} — you can pause or leave this page.`,
      });
    } catch (err) {
      toast({
        title: 'Download could not start',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    }
  }, [refreshDownloads]);

  const onDownloadClick = useCallback(
    (entry: ModelCatalogEntry) => {
      const available = caps?.storageQuota
        ? caps.storageQuota.quota - caps.storageQuota.usage
        : null;
      if (available != null && entry.sizeBytes > available) {
        setConfirmingEntry(entry);
        return;
      }
      void startDownload(entry);
    },
    [caps, startDownload]
  );

  const importFile = useCallback(
    async (file: File) => {
      setImporting(true);
      try {
        const manifest = await modelService.importLocalModel(file);
        toast({
          title: 'Model imported',
          description: `${manifest.name} · ${formatBytes(manifest.sizeBytes)} stored on this device.`,
        });
      } catch (err) {
        toast({
          title: 'Import failed',
          description:
            err instanceof Error
              ? err.message
              : 'The file could not be imported.',
          variant: 'destructive',
        });
      } finally {
        setImporting(false);
        if (fileInputRef.current) fileInputRef.current.value = '';
      }
    },
    []
  );

  const confirmDelete = useCallback(async () => {
    if (!deleting) return;
    const target = deleting;
    setDeleting(null);
    try {
      await modelService.deleteModel(target.id);
      toast({
        title: 'Model deleted',
        description: `${formatBytes(target.sizeBytes)} freed. You can re-download it from the catalog anytime.`,
      });
    } catch (err) {
      toast({
        title: 'Delete failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    }
  }, [deleting]);

  const availableBytes =
    caps?.storageQuota && caps.storageQuota.quota > caps.storageQuota.usage
      ? caps.storageQuota.quota - caps.storageQuota.usage
      : null;

  /* ------------------------------ render ----------------------------- */

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-24 pt-6 sm:px-6">
        <PageHeader
          title="Models"
          description="Download verified GGUF models to this browser, or import your own."
          actions={
            <>
              <Button
                variant="outline"
                onClick={() => router.navigate('/app/models/discover')}
                aria-label="Discover models on Hugging Face"
              >
                <Search aria-hidden />
                Discover on Hugging Face
              </Button>
              <Button
                onClick={() => fileInputRef.current?.click()}
                disabled={importing || caps?.opfs === false}
                aria-label="Import a local GGUF file"
              >
                <Upload aria-hidden />
                {importing ? 'Importing…' : 'Import GGUF'}
              </Button>
              <input
                ref={fileInputRef}
                type="file"
                accept=".gguf,application/octet-stream"
                className="hidden"
                aria-hidden
                tabIndex={-1}
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) void importFile(file);
                }}
              />
            </>
          }
        />

        {/* ---------------------- capability banner ---------------------- */}
        <Section
          title="Browser capabilities"
          description={caps ? capabilityHeadline(caps) : 'Scanning this browser…'}
          className="mb-6"
        >
          {caps ? (
            <div className="flex flex-wrap items-center gap-2">
              <CapChip
                label={caps.webgpu ? 'WebGPU' : 'WebGPU unavailable'}
                ok={caps.webgpu}
                hint="GPU acceleration for in-browser inference"
              />
              <CapChip
                label={caps.wasmSimd ? 'WASM SIMD' : 'WASM SIMD unavailable'}
                ok={caps.wasmSimd}
                hint="CPU fallback with SIMD acceleration"
              />
              <CapChip
                label={caps.opfs ? 'Private storage (OPFS)' : 'OPFS unavailable'}
                ok={caps.opfs}
                hint="Where model bytes are stored, never uploaded"
              />
              {caps.storageQuota && (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-muted px-2.5 py-1 text-xs text-muted-foreground">
                  <HardDrive className="h-3.5 w-3.5" aria-hidden />
                  {formatBytes(caps.storageQuota.usage)} used of{' '}
                  {formatBytes(caps.storageQuota.quota)} storage
                  {availableBytes != null && availableBytes < 600_000_000 && (
                    <span className="text-warning">· low headroom</span>
                  )}
                </span>
              )}
            </div>
          ) : (
            <Skeleton className="h-8 w-72" />
          )}
        </Section>

        {/* -------------------------- installed ------------------------- */}
        <Section
          title="Installed"
          description="Models stored in this browser's private storage. Nothing is uploaded."
          className="mb-6"
        >
          {manifests === null ? (
            <div className="space-y-2">
              <Skeleton className="h-16 w-full" />
              <Skeleton className="h-16 w-full" />
            </div>
          ) : manifests.length === 0 ? (
            <EmptyState
              icon={Package}
              title="No models installed"
              description="Download one from the catalog below, or import a .gguf file you already have."
            />
          ) : (
            <ul className="space-y-2">
              {manifests.map((m) => (
                <li key={m.id}>
                  <div className="group flex items-center gap-3 rounded-xl border border-border bg-background/50 p-3 transition-colors hover:border-brand-strong/60">
                    <div className="rounded-lg bg-muted p-2">
                      <Cpu className="h-4 w-4 text-muted-foreground" aria-hidden />
                    </div>
                    <button
                      type="button"
                      className="min-w-0 flex-1 text-left outline-none focus-visible:ring-2 focus-visible:ring-ring rounded-lg"
                      onClick={() => router.navigate(`/app/models/${m.id}`)}
                      aria-label={`View details for ${m.name}`}
                    >
                      <span className="flex flex-wrap items-center gap-2">
                        <span className="truncate text-sm font-medium">
                          {m.name}
                        </span>
                        {m.verified && (
                          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-success">
                            <CheckCircle2 className="h-3 w-3" aria-hidden />
                            verified
                          </span>
                        )}
                      </span>
                      <span className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
                        <span>{formatBytes(m.sizeBytes)}</span>
                        {m.quantization && (
                          <MetaPill>{m.quantization}</MetaPill>
                        )}
                        <span aria-hidden>·</span>
                        <span>downloaded {formatRelativeTime(m.downloadedAt)}</span>
                        <span aria-hidden>·</span>
                        <span>
                          {m.lastUsedAt
                            ? `last used ${formatRelativeTime(m.lastUsedAt)}`
                            : 'not used yet'}
                        </span>
                      </span>
                    </button>
                    <div className="flex items-center gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => router.navigate(`/app/models/${m.id}`)}
                        aria-label={`Open ${m.name}`}
                      >
                        <ChevronRight aria-hidden />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="text-muted-foreground hover:text-destructive"
                        onClick={() => setDeleting(m)}
                        aria-label={`Delete ${m.name}`}
                      >
                        <Trash2 aria-hidden />
                      </Button>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Section>

        {/* --------------------------- catalog -------------------------- */}
        <Section
          title="Catalog — browser models"
          description="Curated small GGUF models. Downloads are real, resumable and checksum-verified on this device. Browser GGUF inference ships with the WebGPU runtime build — running these models in-chat requires the desktop WebGPU build."
        >
          {caps?.opfs === false && (
            <p className="mb-4 rounded-xl border border-warning/40 bg-warning/10 p-3 text-xs text-foreground">
              This browser has no private file system (OPFS), so downloads
              cannot be stored. Importing is disabled too.
            </p>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            {catalog.map((entry) => (
              <CatalogCard
                key={entry.id}
                entry={entry}
                task={pickTask(downloads, entry.id)}
                manifest={manifests?.find((m) => m.catalogId === entry.id)}
                opfsAvailable={caps?.opfs !== false}
                onDownload={() => onDownloadClick(entry)}
                onPause={() => {
                  const t = pickTask(downloads, entry.id);
                  if (t) modelService.pause(t.id);
                }}
                onResume={() => {
                  const t = pickTask(downloads, entry.id);
                  if (t) void modelService.resume(t.id);
                }}
                onCancel={() => {
                  const t = pickTask(downloads, entry.id);
                  if (t) void modelService.cancel(t.id);
                }}
                onOpenManifest={(id) => router.navigate(`/app/models/${id}`)}
              />
            ))}
          </div>
        </Section>
      </div>

      {/* Delete confirmation */}
      <AlertDialog
        open={deleting !== null}
        onOpenChange={(open) => !open && setDeleting(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete {deleting?.name}?</AlertDialogTitle>
            <AlertDialogDescription>
              This permanently removes the model file from this browser's
              storage and frees {formatBytes(deleting?.sizeBytes ?? 0)}. You can
              download it again from the catalog anytime.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep it</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-white hover:bg-destructive/90"
              onClick={() => void confirmDelete()}
            >
              Delete model
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Low-storage confirmation before a big download */}
      <AlertDialog
        open={confirmingEntry !== null}
        onOpenChange={(open) => !open && setConfirmingEntry(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Not enough storage headroom</AlertDialogTitle>
            <AlertDialogDescription>
              {confirmingEntry?.name} needs about{' '}
              {formatBytes(confirmingEntry?.sizeBytes ?? 0)}, but this browser
              only has an estimated {formatBytes(availableBytes ?? 0)} available.
              The download may fail part-way. Continue anyway?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                if (confirmingEntry) void startDownload(confirmingEntry);
                setConfirmingEntry(null);
              }}
            >
              Download anyway
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

/* ----------------------------- catalog card ---------------------------- */

function CatalogCard({
  entry,
  task,
  manifest,
  opfsAvailable,
  onDownload,
  onPause,
  onResume,
  onCancel,
  onOpenManifest,
}: {
  entry: ModelCatalogEntry;
  task?: DownloadTask;
  manifest?: ModelManifest;
  opfsAvailable: boolean;
  onDownload: () => void;
  onPause: () => void;
  onResume: () => void;
  onCancel: () => void;
  onOpenManifest: (manifestId: string) => void;
}) {
  const active = task && ACTIVE_STATES.includes(task.state);
  const pct =
    task && task.bytesTotal > 0
      ? Math.min(100, Math.round((task.bytesDownloaded / task.bytesTotal) * 100))
      : 0;

  return (
    <article className="flex flex-col gap-3 rounded-2xl border border-border bg-card p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            {tierBadge(entry.tier)}
            <h3 className="truncate text-sm font-semibold">{entry.name}</h3>
          </div>
          <p className="mt-0.5 text-xs text-muted-foreground">
            by {entry.author}
          </p>
        </div>
        {manifest && (
          <Button
            variant="outline"
            size="sm"
            onClick={() => onOpenManifest(manifest.id)}
            aria-label={`Open installed ${entry.name}`}
          >
            Installed — open
          </Button>
        )}
      </div>

      <p className="text-[13px] leading-relaxed text-muted-foreground">
        {entry.description}
      </p>

      <div className="flex flex-wrap gap-1.5">
        <MetaPill>{entry.paramsClass} params</MetaPill>
        <MetaPill>{entry.quantization}</MetaPill>
        <MetaPill>{formatContext(entry.contextLimit)}</MetaPill>
        <MetaPill tone="outline">{formatBytes(entry.sizeBytes)}</MetaPill>
        <MetaPill tone="outline">{entry.license}</MetaPill>
      </div>

      <p className="text-[11px] text-muted-foreground">
        Tools unknown · Vision unknown · Embeddings unknown — capabilities stay
        unknown until verified on this device.
      </p>

      {/* Download area — one of: idle | active | done | failed | cancelled */}
      {(!task || task.state === 'cancelled') && !manifest && (
        <div className="mt-auto pt-1">
          <Button
            size="sm"
            onClick={onDownload}
            disabled={!opfsAvailable}
            aria-label={`Download ${entry.name} (${formatBytes(entry.sizeBytes)})`}
          >
            <Download aria-hidden />
            Download · {formatBytes(entry.sizeBytes)}
          </Button>
        </div>
      )}

      {active && task && (
        <div className="mt-auto space-y-2 pt-1" aria-live="polite">
          <div className="flex items-center justify-between text-xs">
            <StatusDot
              tone={
                task.state === 'paused'
                  ? 'warning'
                  : task.state === 'failed'
                    ? 'error'
                    : 'accent'
              }
            >
              {STATE_LABELS[task.state]}
            </StatusDot>
            <span className="font-mono text-muted-foreground">
              {formatBytes(task.bytesDownloaded)} / {formatBytes(task.bytesTotal)}{' '}
              · {pct}%
            </span>
          </div>
          <Progress
            value={pct}
            aria-label={`${entry.name} download progress: ${pct}%`}
          />
          <div className="flex flex-wrap gap-2">
            {['queued', 'downloading'].includes(task.state) && (
              <Button variant="outline" size="sm" onClick={onPause}>
                <Pause aria-hidden />
                Pause
              </Button>
            )}
            {task.state === 'paused' && (
              <Button variant="outline" size="sm" onClick={onResume}>
                <Play aria-hidden />
                Resume
              </Button>
            )}
            {['queued', 'downloading', 'paused'].includes(task.state) && (
              <Button
                variant="ghost"
                size="sm"
                onClick={onCancel}
                className="text-muted-foreground hover:text-destructive"
              >
                <X aria-hidden />
                Cancel
              </Button>
            )}
          </div>
        </div>
      )}

      {task?.state === 'ready' && (
        <div className="mt-auto pt-1">
          <p className="inline-flex items-center gap-1.5 text-xs font-medium text-success">
            <CheckCircle2 className="h-3.5 w-3.5" aria-hidden />
            Downloaded &amp; verified
          </p>
        </div>
      )}

      {task?.state === 'failed' && (
        <div className="mt-auto space-y-2 pt-1">
          <p className="rounded-lg border border-destructive/40 bg-destructive/10 p-2 text-xs text-destructive">
            {task.error ?? 'The download failed.'}
          </p>
          <Button variant="outline" size="sm" onClick={onDownload}>
            Retry download
          </Button>
        </div>
      )}
    </article>
  );
}
