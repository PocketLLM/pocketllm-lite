'use client';

/**
 * ModelDetailView — one installed model manifest.
 *
 * Honest status: what is verified, what stays unknown, and where the
 * model can actually be used in this build.
 */
import { useCallback, useEffect, useState } from 'react';
import {
  ArrowLeft,
  BadgeCheck,
  CheckCircle2,
  CircleHelp,
  Copy,
  Cpu,
  FileBadge,
  Package,
  Trash2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
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
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { EmptyState, MetaPill, Section } from '@/features/app/shared/ui';
import { modelService } from '@/lib/services/model-service';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { formatBytes, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { ModelManifest } from '@/lib/types/domain';

function formatDate(ts: number): string {
  return new Date(ts).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

/** A label + value row inside the status section. */
function StatusRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1 border-b border-border py-3 last:border-0 sm:flex-row sm:items-baseline sm:gap-4">
      <dt className="w-40 shrink-0 text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </dt>
      <dd className="min-w-0 text-sm">{children}</dd>
    </div>
  );
}

export function ModelDetailView({ modelId }: { modelId: string }) {
  const [manifest, setManifest] = useState<ModelManifest | null | undefined>(
    undefined
  ); // undefined = loading, null = not found
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async () => {
    try {
      const all = await modelService.installed();
      setManifest(all.find((m) => m.id === modelId) ?? null);
    } catch (err) {
      console.error('[model-detail] load failed', err);
      setManifest(null);
    }
  }, [modelId]);

  useEffect(() => {
    setManifest(undefined);
    void load();
    const un = bus.on('models:changed', () => void load());
    return () => un();
  }, [load]);

  const copySha = useCallback(async (sha: string) => {
    try {
      await navigator.clipboard.writeText(sha);
      toast({ title: 'Checksum copied' });
    } catch {
      toast({
        title: 'Copy failed',
        description: 'Your browser blocked clipboard access.',
        variant: 'destructive',
      });
    }
  }, []);

  const doDelete = useCallback(async () => {
    if (!manifest) return;
    setDeleting(true);
    try {
      await modelService.deleteModel(manifest.id);
      toast({
        title: 'Model deleted',
        description: `${formatBytes(manifest.sizeBytes)} freed.`,
      });
      router.navigate('/app/models');
    } catch (err) {
      toast({
        title: 'Delete failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
      setDeleting(false);
    }
  }, [manifest]);

  /* ------------------------------ states ----------------------------- */

  if (manifest === undefined) {
    return (
      <div className="flex-1 overflow-y-auto scrollbar-slim">
        <div className="mx-auto w-full max-w-3xl space-y-4 px-4 py-6 sm:px-6">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-6 w-64" />
          <Skeleton className="h-48 w-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      </div>
    );
  }

  if (manifest === null) {
    return (
      <div className="flex-1 overflow-y-auto scrollbar-slim">
        <div className="mx-auto w-full max-w-3xl px-4 py-6 sm:px-6">
          <EmptyState
            icon={Package}
            title="Model not found"
            description="This model is not installed in this browser. It may have been deleted."
            action={
              <Button variant="outline" onClick={() => router.navigate('/app/models')}>
                <ArrowLeft aria-hidden />
                Back to Models
              </Button>
            }
          />
        </div>
      </div>
    );
  }

  /* ------------------------------ detail ----------------------------- */

  const sha = manifest.sha256;

  return (
    <TooltipProvider delayDuration={150}>
      <div className="flex-1 overflow-y-auto scrollbar-slim">
        <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-6 sm:px-6">
          <Button
            variant="ghost"
            size="sm"
            className="-ml-2 mb-2 text-muted-foreground"
            onClick={() => router.navigate('/app/models')}
            aria-label="Back to Models"
          >
            <ArrowLeft aria-hidden />
            Models
          </Button>

          <div className="flex items-start gap-4 pb-6">
            <div className="mt-1 hidden rounded-xl bg-muted p-2.5 sm:block">
              <Cpu className="h-5 w-5 text-muted-foreground" aria-hidden />
            </div>
            <div className="min-w-0">
              <h1 className="font-display text-xl font-semibold tracking-tight sm:text-2xl">
                {manifest.name}
              </h1>
              <div className="mt-2 flex flex-wrap gap-1.5">
                <MetaPill tone="accent">Browser GGUF</MetaPill>
                {manifest.quantization && <MetaPill>{manifest.quantization}</MetaPill>}
                {manifest.paramsClass && <MetaPill>{manifest.paramsClass}</MetaPill>}
                <MetaPill tone="outline">{formatBytes(manifest.sizeBytes)}</MetaPill>
              </div>
            </div>
          </div>

          {/* ------------------------- status ------------------------- */}
          <Section
            title="Status"
            className="mb-6"
          >
            <dl>
              <StatusRow label="State">
                <span className="inline-flex items-center gap-1.5 font-medium text-success">
                  <CheckCircle2 className="h-4 w-4" aria-hidden />
                  Ready — stored on this device
                </span>
              </StatusRow>
              <StatusRow label="Runtime">
                Browser GGUF (WebGPU runtime build)
              </StatusRow>
              <StatusRow label="Size">
                {formatBytes(manifest.sizeBytes)}
                <span className="ml-2 font-mono text-xs text-muted-foreground">
                  {manifest.fileName}
                </span>
              </StatusRow>
              <StatusRow label="Downloaded">
                {formatDate(manifest.downloadedAt)}
                <span className="ml-2 text-xs text-muted-foreground">
                  ({formatRelativeTime(manifest.downloadedAt)})
                </span>
              </StatusRow>
              <StatusRow label="Last used">
                {manifest.lastUsedAt
                  ? `${formatDate(manifest.lastUsedAt)} (${formatRelativeTime(manifest.lastUsedAt)})`
                  : 'Not used yet'}
              </StatusRow>
              <StatusRow label="Compatibility">
                {manifest.verified ? (
                  <span className="inline-flex items-center gap-1.5 text-success">
                    <BadgeCheck className="h-4 w-4" aria-hidden />
                    Verified on this browser
                  </span>
                ) : (
                  <span className="text-warning">Not verified on this browser</span>
                )}
              </StatusRow>
              <StatusRow label="SHA-256">
                {sha ? (
                  <span className="flex flex-wrap items-center gap-2">
                    <code className="break-all rounded bg-muted px-2 py-1 font-mono text-xs">
                      {sha.slice(0, 16)}…{sha.slice(-8)}
                    </code>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7"
                      onClick={() => void copySha(sha)}
                      aria-label="Copy full SHA-256 checksum"
                    >
                      <Copy className="h-3.5 w-3.5" aria-hidden />
                    </Button>
                  </span>
                ) : (
                  <span className="text-muted-foreground">
                    No pinned checksum for this model — verification used the
                    GGUF header instead.
                  </span>
                )}
              </StatusRow>
            </dl>
          </Section>

          {/* ---------------------- capabilities ---------------------- */}
          <Section
            title="Capabilities"
            description="Only what has actually been verified. Nothing is inferred from the filename."
            className="mb-6"
          >
            <ul className="space-y-3">
              <li className="flex items-center justify-between gap-3">
                <span className="text-sm">Text generation</span>
                <span className="inline-flex items-center gap-1.5 text-xs font-medium text-success">
                  <CheckCircle2 className="h-3.5 w-3.5" aria-hidden />
                  Verified by GGUF load
                </span>
              </li>
              {(
                [
                  ['Tools', manifest.capabilities.tools],
                  ['Vision', manifest.capabilities.vision],
                  ['Embeddings', manifest.capabilities.embeddings],
                ] as const
              ).map(([label, value]) => (
                <li
                  key={label}
                  className="flex items-center justify-between gap-3"
                >
                  <span className="text-sm">{label}</span>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <button
                        type="button"
                        className="inline-flex cursor-help items-center gap-1 rounded-full border border-dashed border-border px-2.5 py-1 text-xs text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
                        aria-label={`${label} capability: unknown. More info.`}
                      >
                        <CircleHelp className="h-3.5 w-3.5" aria-hidden />
                        unknown
                      </button>
                    </TooltipTrigger>
                    <TooltipContent className="max-w-64 text-xs">
                      Capability stays unknown until verified — PocketLLM never
                      guesses from filenames.
                    </TooltipContent>
                  </Tooltip>
                </li>
              ))}
            </ul>
          </Section>

          {/* -------------------- where it can be used ------------------ */}
          <Section
            title="Where this model can be used"
            className="mb-6"
          >
            <div className="flex gap-3">
              <FileBadge
                className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground"
                aria-hidden
              />
              <div className="space-y-2 text-[13px] leading-relaxed text-muted-foreground">
                <p>
                  The model file lives in this browser&apos;s private storage
                  (OPFS) — it never leaves your device and is never uploaded.
                </p>
                <p>
                  Browser GGUF inference ships with the WebGPU runtime build:
                  downloads here are real and checksum-verified, but running
                  this model in-chat requires the desktop WebGPU build of
                  PocketLLM. This Lite Web build chats through the built-in
                  Assist runtime, or through Ollama / OpenAI-compatible
                  endpoints you connect in Providers.
                </p>
              </div>
            </div>
          </Section>

          {/* ------------------------ danger zone ---------------------- */}
          <Section
            title="Danger zone"
            className="border-destructive/30"
          >
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="text-sm font-medium">Delete this model</p>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  Frees {formatBytes(manifest.sizeBytes)} of storage on this
                  device. You can download it again from the catalog anytime.
                </p>
              </div>
              <Button
                variant="destructive"
                onClick={() => setConfirmOpen(true)}
                disabled={deleting}
                aria-label={`Delete ${manifest.name}`}
              >
                <Trash2 aria-hidden />
                {deleting ? 'Deleting…' : 'Delete model'}
              </Button>
            </div>
          </Section>
        </div>
      </div>

      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete {manifest.name}?</AlertDialogTitle>
            <AlertDialogDescription>
              This permanently removes the model file from this browser&apos;s
              storage and frees {formatBytes(manifest.sizeBytes)}. This cannot
              be undone, but the model can be re-downloaded from the catalog.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep it</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-white hover:bg-destructive/90"
              onClick={() => void doDelete()}
            >
              Delete model
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </TooltipProvider>
  );
}
