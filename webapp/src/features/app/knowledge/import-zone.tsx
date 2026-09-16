'use client';

/**
 * ImportZone — drag-and-drop target + hidden file picker for the
 * knowledge base. Keyboard users get the equivalent "Browse files"
 * button; the hidden input is reset after each pick so the same file
 * can be re-imported later.
 */
import { useRef, useState } from 'react';
import { FolderOpen, UploadCloud } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

export const ACCEPT_ATTRIBUTE = '.pdf,.txt,.md,.markdown,.csv,.tsv';

export function ImportZone({
  onFiles,
  inputRef,
  busy = false,
}: {
  onFiles: (files: File[]) => void;
  /** Shared ref so the page header button can open the same picker. */
  inputRef: React.RefObject<HTMLInputElement | null>;
  /** Highlights the zone while any import is running. */
  busy?: boolean;
}) {
  const [dragging, setDragging] = useState(false);
  const dragDepth = useRef(0);

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    dragDepth.current = 0;
    setDragging(false);
    const files = Array.from(e.dataTransfer.files ?? []);
    if (files.length > 0) onFiles(files);
  };

  return (
    <div
      onDragEnter={(e) => {
        e.preventDefault();
        dragDepth.current += 1;
        setDragging(true);
      }}
      onDragOver={(e) => e.preventDefault()}
      onDragLeave={(e) => {
        e.preventDefault();
        dragDepth.current -= 1;
        if (dragDepth.current <= 0) {
          dragDepth.current = 0;
          setDragging(false);
        }
      }}
      onDrop={handleDrop}
      className={cn(
        'flex flex-col items-start justify-between gap-3 rounded-2xl border border-dashed p-4 transition-colors sm:flex-row sm:items-center sm:gap-4',
        dragging || busy
          ? 'border-brand-strong bg-brand/10'
          : 'border-border bg-card/60 hover:border-brand-strong/60'
      )}
      aria-label="Import documents — drop files here"
    >
      <div className="flex min-w-0 items-center gap-3">
        <span
          aria-hidden="true"
          className={cn(
            'shrink-0 rounded-xl border p-2.5 transition-colors',
            dragging || busy
              ? 'border-brand-strong bg-brand text-brand-foreground'
              : 'border-border bg-muted text-muted-foreground'
          )}
        >
          <UploadCloud className="h-5 w-5" />
        </span>
        <div className="min-w-0">
          <p className="text-sm font-medium">Drop files to import</p>
          <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">
            PDF, TXT, MD, CSV, TSV — up to 150 MB each. PDFs must contain real text; scanned,
            image-only PDFs are refused honestly (no fake OCR).
          </p>
        </div>
      </div>

      <input
        ref={inputRef}
        type="file"
        multiple
        accept={ACCEPT_ATTRIBUTE}
        className="hidden"
        tabIndex={-1}
        aria-hidden="true"
        onChange={(e) => {
          const files = Array.from(e.target.files ?? []);
          if (files.length > 0) onFiles(files);
          e.target.value = ''; // allow re-importing the same file later
        }}
      />
      <Button
        type="button"
        variant="outline"
        size="sm"
        className="shrink-0"
        onClick={() => inputRef.current?.click()}
      >
        <FolderOpen className="h-4 w-4" />
        Browse files
      </Button>
    </div>
  );
}
