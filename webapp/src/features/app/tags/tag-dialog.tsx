'use client';

/**
 * TagDialog — create / edit dialog for tags.
 * Name + preset color swatch picker; writes via tagRepo and emits
 * the tags:changed domain event so every list refreshes.
 */
import { useEffect, useState } from 'react';
import { Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { bus } from '@/lib/core/events/event-bus';
import { tagRepo } from '@/lib/core/db/repositories';
import type { Tag } from '@/lib/types/domain';
import { cn, uuid } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';

/** Preset palette — earthy tones that read on both light and dark. */
export const TAG_COLORS = [
  '#FFEF4D',
  '#F0DE20',
  '#2F7D4F',
  '#B4770F',
  '#C2412E',
  '#3D6A7D',
  '#6E6A5E',
  '#1B2430',
] as const;

export function TagDialog({
  open,
  onOpenChange,
  tag,
  defaultColor = TAG_COLORS[0],
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Tag being edited, or null when creating. */
  tag: Tag | null;
  /** Suggested color for new tags (rotated by the caller). */
  defaultColor?: string;
}) {
  const [name, setName] = useState('');
  const [color, setColor] = useState<string>(defaultColor);
  const [busy, setBusy] = useState(false);

  // Reset the form each time the dialog opens.
  useEffect(() => {
    if (open) {
      setName(tag?.name ?? '');
      setColor(tag?.color ?? defaultColor);
    }
  }, [open, tag, defaultColor]);

  const trimmed = name.trim();

  const save = async () => {
    if (!trimmed) return;
    setBusy(true);
    try {
      if (tag) {
        await tagRepo.put({ ...tag, name: trimmed, color });
        toast({ title: 'Tag updated', description: `“${trimmed}” saved.` });
      } else {
        await tagRepo.put({
          id: uuid(),
          name: trimmed,
          color,
          createdAt: Date.now(),
        });
        toast({ title: 'Tag created', description: `“${trimmed}” is ready to use on chats.` });
      }
      bus.emit('tags:changed');
      onOpenChange(false);
    } catch (err) {
      toast({
        title: 'Could not save tag',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={(o) => !busy && onOpenChange(o)}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>{tag ? 'Edit tag' : 'New tag'}</DialogTitle>
          <DialogDescription>
            Tags are private to this device. Assign them to chats from the
            History view to keep conversations organized.
          </DialogDescription>
        </DialogHeader>

        <form
          className="space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            void save();
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor="tag-name">Name</Label>
            <Input
              id="tag-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. research"
              maxLength={30}
              autoFocus
              aria-describedby="tag-name-hint"
            />
            <p id="tag-name-hint" className="text-xs text-muted-foreground">
              Up to 30 characters.
            </p>
          </div>

          <fieldset className="space-y-1.5">
            <legend className="text-sm font-medium">Color</legend>
            <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="Tag color">
              {TAG_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  role="radio"
                  aria-checked={color === c}
                  aria-label={`Use color ${c}`}
                  onClick={() => setColor(c)}
                  className={cn(
                    'h-8 w-8 rounded-full border border-black/10 transition-transform focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background dark:border-white/10',
                    color === c
                      ? 'scale-110 ring-2 ring-ring ring-offset-2 ring-offset-background'
                      : 'hover:scale-110'
                  )}
                  style={{ backgroundColor: c }}
                />
              ))}
            </div>
          </fieldset>

          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || !trimmed}>
              {busy && <Loader2 className="h-4 w-4 animate-spin" />}
              {tag ? 'Save changes' : 'Create tag'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
