'use client';

/**
 * PromptDialog — create or edit a reusable prompt.
 *
 * Writes through promptRepo and emits 'prompts:changed' so every
 * list view refreshes.
 */
import { useEffect, useState } from 'react';
import { Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { promptRepo } from '@/lib/core/db/repositories';
import { uuid } from '@/lib/utils';
import type { Prompt } from '@/lib/types/domain';

export function PromptDialog({
  open,
  onOpenChange,
  /** The prompt being edited, or null when creating. */
  prompt,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  prompt: Prompt | null;
}) {
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('');
  const [body, setBody] = useState('');
  const [saving, setSaving] = useState(false);

  // Reset the form each time the dialog opens.
  useEffect(() => {
    if (!open) return;
    setTitle(prompt?.title ?? '');
    setCategory(prompt?.category ?? '');
    setBody(prompt?.body ?? '');
    setSaving(false);
  }, [open, prompt]);

  const canSave = title.trim().length > 0 && body.trim().length > 0 && !saving;

  const handleSave = async () => {
    setSaving(true);
    const now = Date.now();
    try {
      if (prompt) {
        await promptRepo.put({
          ...prompt,
          title: title.trim(),
          category: category.trim() || undefined,
          body: body.trim(),
          updatedAt: now,
        });
        toast({ title: 'Prompt updated' });
      } else {
        await promptRepo.put({
          id: uuid(),
          title: title.trim(),
          category: category.trim() || undefined,
          body: body.trim(),
          createdAt: now,
          updatedAt: now,
        });
        toast({ title: 'Prompt created' });
      }
      bus.emit('prompts:changed');
      onOpenChange(false);
    } catch (err) {
      toast({
        title: prompt ? 'Could not update prompt' : 'Could not create prompt',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85vh] overflow-y-auto scrollbar-slim sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{prompt ? 'Edit prompt' : 'New prompt'}</DialogTitle>
          <DialogDescription>
            A reusable system prompt or message starter you can load into any
            chat.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="prompt-title">Title</Label>
            <Input
              id="prompt-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={120}
              placeholder="e.g. Code review checklist"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="prompt-category">Category</Label>
            <Input
              id="prompt-category"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              maxLength={60}
              placeholder="e.g. Writing (optional)"
            />
            <p className="text-[11px] text-muted-foreground">
              Categories become filter chips on the prompts page.
            </p>
          </div>

          <div className="grid gap-2">
            <Label htmlFor="prompt-body">Body</Label>
            <Textarea
              id="prompt-body"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={8}
              placeholder="Paste or write the prompt text…"
              aria-describedby="prompt-body-hint"
            />
            <p id="prompt-body-hint" className="text-[11px] text-muted-foreground">
              “Use in chat” opens a new chat with this text in the composer —
              you can edit it before sending.
            </p>
          </div>
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={saving}
          >
            Cancel
          </Button>
          <Button onClick={() => void handleSave()} disabled={!canSave}>
            {saving && <Loader2 className="animate-spin" aria-hidden />}
            {prompt ? 'Save changes' : 'Create prompt'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
