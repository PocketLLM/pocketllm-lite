'use client';

/**
 * DeleteDocumentDialog — destructive confirm with the exact plan
 * semantics: source + chunks + embeddings are deleted; existing chat
 * citations keep tombstone metadata.
 */
import { useState } from 'react';
import { Trash2 } from 'lucide-react';
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
import { toast } from '@/hooks/use-toast';
import { documentService } from '@/lib/services/document-service';
import type { DocumentRecord } from '@/lib/types/domain';

export function DeleteDocumentDialog({
  doc,
  open,
  onOpenChange,
  onDeleted,
}: {
  doc: DocumentRecord | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Called after a successful delete (e.g. navigate back). */
  onDeleted?: () => void;
}) {
  const [deleting, setDeleting] = useState(false);

  const handleDelete = async () => {
    if (!doc || deleting) return;
    setDeleting(true);
    try {
      await documentService.delete(doc.id);
      toast({
        title: 'Document deleted',
        description: `“${doc.name}” — source, chunks and embeddings removed from this browser.`,
      });
      onOpenChange(false);
      onDeleted?.();
    } catch (err) {
      toast({
        title: 'Delete failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setDeleting(false);
    }
  };

  return (
    <AlertDialog open={open && !!doc} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete “{doc?.name}”?</AlertDialogTitle>
          <AlertDialogDescription>
            Deletes source + chunks + embeddings. Existing chat citations keep tombstone metadata — the
            document name and excerpt stay visible, but its text is no longer retrievable.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={deleting}>Cancel</AlertDialogCancel>
          <AlertDialogAction
            disabled={deleting}
            onClick={(e) => {
              e.preventDefault(); // stay open until the async delete settles
              void handleDelete();
            }}
            className="bg-destructive text-white hover:bg-destructive/90 focus-visible:ring-destructive/20"
          >
            <Trash2 className="h-4 w-4" />
            {deleting ? 'Deleting…' : 'Delete document'}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
