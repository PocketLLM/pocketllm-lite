'use client';

/**
 * MemoryDialog — add or edit a memory.
 *
 * One form for both flows. Saving goes through memoryService, which
 * runs the same sensitive-content guard as automatic extraction and
 * throws an honest error message shown as a destructive toast.
 */
import { useEffect, useState } from 'react';
import { Loader2, ShieldCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Slider } from '@/components/ui/slider';
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
import { memoryService } from '@/lib/services/memory-service';
import type { Memory } from '@/lib/types/domain';

const TYPE_OPTIONS: { value: Memory['type']; label: string }[] = [
  { value: 'fact', label: 'Fact' },
  { value: 'preference', label: 'Preference' },
  { value: 'instruction', label: 'Instruction' },
  { value: 'context', label: 'Context' },
];

export function MemoryDialog({
  open,
  onOpenChange,
  /** The memory being edited, or null when creating. */
  memory,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  memory: Memory | null;
}) {
  const [fact, setFact] = useState('');
  const [subject, setSubject] = useState('');
  const [type, setType] = useState<Memory['type']>('fact');
  const [confidence, setConfidence] = useState(0.8);
  const [saving, setSaving] = useState(false);

  // Reset the form each time the dialog opens.
  useEffect(() => {
    if (!open) return;
    setFact(memory?.fact ?? '');
    setSubject(
      memory?.subject && memory.subject !== 'general' ? memory.subject : ''
    );
    setType(memory?.type ?? 'fact');
    setConfidence(memory?.confidence ?? 0.8);
    setSaving(false);
  }, [open, memory]);

  const canSave = fact.trim().length > 0 && !saving;

  const handleSave = async () => {
    setSaving(true);
    try {
      if (memory) {
        await memoryService.update(memory.id, {
          fact: fact.trim(),
          subject: subject.trim() || 'general',
          type,
          confidence,
        });
        toast({ title: 'Memory updated' });
      } else {
        await memoryService.create(fact.trim(), {
          subject: subject.trim() || undefined,
          type,
          confidence,
        });
        toast({
          title: 'Memory added',
          description:
            'It will be injected into chats where memory is enabled.',
        });
      }
      onOpenChange(false);
    } catch (err) {
      toast({
        title: memory ? 'Could not update memory' : 'Could not add memory',
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
          <DialogTitle>{memory ? 'Edit memory' : 'Add memory'}</DialogTitle>
          <DialogDescription>
            {memory
              ? 'Update what PocketLLM remembers about you.'
              : 'A fact or preference PocketLLM can inject into chats where memory is enabled.'}
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="memory-fact">Fact</Label>
            <Textarea
              id="memory-fact"
              value={fact}
              onChange={(e) => setFact(e.target.value)}
              rows={3}
              maxLength={500}
              placeholder="e.g. Prefers concise answers with code examples"
              aria-describedby="memory-fact-hint"
            />
            <p id="memory-fact-hint" className="text-[11px] text-muted-foreground">
              {fact.trim().length}/500 characters
            </p>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="memory-subject">Subject</Label>
              <Input
                id="memory-subject"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                maxLength={120}
                placeholder="general"
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="memory-type">Type</Label>
              <Select value={type} onValueChange={(v) => setType(v as Memory['type'])}>
                <SelectTrigger id="memory-type" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {TYPE_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid gap-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="memory-confidence">Confidence</Label>
              <span className="text-xs tabular-nums text-muted-foreground">
                {Math.round(confidence * 100)}%
              </span>
            </div>
            <Slider
              id="memory-confidence"
              aria-label="Confidence"
              value={[confidence]}
              min={0}
              max={1}
              step={0.05}
              onValueChange={([v]) => setConfidence(v)}
            />
            <p className="text-[11px] text-muted-foreground">
              How sure PocketLLM should be of this fact — low-confidence
              memories are less likely to be included in prompts.
            </p>
          </div>
        </div>

        <p className="flex items-start gap-2 rounded-lg bg-muted p-2.5 text-xs leading-relaxed text-muted-foreground">
          <ShieldCheck className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden />
          Automatic extraction refuses secrets; manual entries go through the
          same guard.
        </p>

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
            {memory ? 'Save changes' : 'Add memory'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
