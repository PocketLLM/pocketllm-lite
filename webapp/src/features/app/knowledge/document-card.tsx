'use client';

/**
 * DocumentCard — one tile in the knowledge grid. The whole card opens
 * the document detail via a stretched button (valid HTML: interactive
 * controls layered above it with a higher z-index).
 */
import { AlertTriangle, ArrowUpRight, Loader2, MessageSquareText, MoreHorizontal, RefreshCw, Trash2, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { MetaPill } from '@/features/app/shared/ui';
import type { DocumentRecord } from '@/lib/types/domain';
import { formatBytes, formatNumber, formatRelativeTime } from '@/lib/utils';
import { DocumentIcon, StatusBadge, isWorkingStatus, typeLabel } from './helpers';

export interface DocumentCardProps {
  doc: DocumentRecord;
  /** Live pipeline message ("Extracting page 3 of 12…"). */
  progressMessage?: string;
  reindexing?: boolean;
  onOpen: (id: string) => void;
  onReindex: (doc: DocumentRecord) => void;
  /** Opens the confirm dialog. */
  onDelete: (doc: DocumentRecord) => void;
  /** Removes a failed import without a dialog. */
  onDismiss: (doc: DocumentRecord) => void;
  /** Knowledge → Chat hand-off ("Ask PocketLLM"). */
  onAsk: (doc: DocumentRecord) => void;
}

export function DocumentCard({
  doc,
  progressMessage,
  reindexing = false,
  onOpen,
  onReindex,
  onDelete,
  onDismiss,
  onAsk,
}: DocumentCardProps) {
  const working = isWorkingStatus(doc.status);
  const canReindex = doc.status === 'ready' && !reindexing;

  return (
    <article className="group relative flex h-full flex-col gap-3 rounded-xl border border-border bg-card p-4 transition-all hover:-translate-y-0.5 hover:border-brand-strong hover:shadow-md">
      {/* Stretched open button — covers the whole card. */}
      <button
        type="button"
        onClick={() => onOpen(doc.id)}
        className="absolute inset-0 z-0 rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background"
        aria-label={`Open ${doc.name}`}
      />

      <div className="relative flex items-start gap-3">
        <span className="mt-0.5 shrink-0 rounded-lg bg-muted p-2 text-muted-foreground">
          <DocumentIcon mimeType={doc.mimeType} name={doc.name} className="h-4 w-4" />
        </span>
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-medium" title={doc.name}>
            {doc.name}
          </h3>
          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
            <StatusBadge status={doc.status} />
            <MetaPill tone="outline">{typeLabel(doc)}</MetaPill>
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="relative z-10 h-7 w-7 shrink-0 rounded-md text-muted-foreground opacity-0 transition-opacity focus-visible:opacity-100 group-hover:opacity-100 data-[state=open]:opacity-100"
              aria-label={`Actions for ${doc.name}`}
            >
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48">
            <DropdownMenuItem onClick={() => onOpen(doc.id)}>
              <ArrowUpRight className="h-4 w-4" />
              Open
            </DropdownMenuItem>
            <DropdownMenuItem
              disabled={doc.status !== 'ready'}
              onClick={() => onAsk(doc)}
            >
              <MessageSquareText className="h-4 w-4" />
              Ask PocketLLM
            </DropdownMenuItem>
            <DropdownMenuItem disabled={!canReindex} onClick={() => onReindex(doc)}>
              <RefreshCw className={reindexing ? 'h-4 w-4 animate-spin' : 'h-4 w-4'} />
              {reindexing ? 'Re-indexing…' : 'Re-index'}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" onClick={() => onDelete(doc)}>
              <Trash2 className="h-4 w-4" />
              Delete…
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Live pipeline progress or honest failure. */}
      {working && (
        <p className="relative flex min-w-0 items-center gap-2 text-xs text-muted-foreground">
          <Loader2 className="h-3.5 w-3.5 shrink-0 animate-spin" aria-hidden="true" />
          <span className="truncate">{progressMessage ?? `${doc.status.charAt(0).toUpperCase()}${doc.status.slice(1)}…`}</span>
        </p>
      )}
      {doc.status === 'failed' && doc.error && (
        <div className="relative">
          <p className="flex items-start gap-2 text-xs leading-relaxed text-destructive">
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
            <span className="line-clamp-3">{doc.error}</span>
          </p>
          <Button
            variant="outline"
            size="sm"
            className="relative z-10 mt-2 h-7 text-xs"
            onClick={() => onDismiss(doc)}
          >
            <X className="h-3.5 w-3.5" />
            Dismiss
          </Button>
        </div>
      )}

      {/* Meta footer. */}
      {doc.status !== 'failed' && (
        <div className="relative mt-auto flex flex-wrap items-center gap-x-2 gap-y-1.5 text-[11px] text-muted-foreground">
          <span className="tabular-nums">{formatBytes(doc.sizeBytes)}</span>
          {doc.pageCount != null && (
            <>
              <span aria-hidden="true">·</span>
              <span className="tabular-nums">{doc.pageCount} pg</span>
            </>
          )}
          <span aria-hidden="true">·</span>
          <span className="tabular-nums">{formatNumber(doc.chunkCount)} chunks</span>
          <MetaPill>{doc.retrievalMode}</MetaPill>
          {doc.indexedAt && (
            <span className="w-full text-muted-foreground/80">
              indexed {formatRelativeTime(doc.indexedAt)}
            </span>
          )}
        </div>
      )}
    </article>
  );
}
