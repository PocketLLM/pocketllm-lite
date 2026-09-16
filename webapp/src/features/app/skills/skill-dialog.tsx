'use client';

/**
 * SkillDialog — create or edit a skill.
 *
 * Writes through skillRepo and emits 'skills:changed' so every view
 * refreshes. The note reminds the user what enabling actually does.
 */
import { useEffect, useState } from 'react';
import { Info, Loader2 } from 'lucide-react';
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
import { skillRepo } from '@/lib/core/db/repositories';
import { uuid } from '@/lib/utils';
import type { Skill } from '@/lib/types/domain';

export function SkillDialog({
  open,
  onOpenChange,
  /** The skill being edited, or null when creating. */
  skill,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  skill: Skill | null;
}) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [instructions, setInstructions] = useState('');
  const [saving, setSaving] = useState(false);

  // Reset the form each time the dialog opens.
  useEffect(() => {
    if (!open) return;
    setName(skill?.name ?? '');
    setDescription(skill?.description ?? '');
    setInstructions(skill?.instructions ?? '');
    setSaving(false);
  }, [open, skill]);

  const canSave = name.trim().length > 0 && instructions.trim().length > 0 && !saving;

  const handleSave = async () => {
    setSaving(true);
    const now = Date.now();
    try {
      if (skill) {
        await skillRepo.put({
          ...skill,
          name: name.trim(),
          description: description.trim(),
          instructions: instructions.trim(),
          updatedAt: now,
        });
        toast({ title: 'Skill updated' });
      } else {
        await skillRepo.put({
          id: uuid(),
          name: name.trim(),
          description: description.trim(),
          instructions: instructions.trim(),
          source: 'local',
          enabled: true,
          createdAt: now,
          updatedAt: now,
        });
        toast({
          title: 'Skill created',
          description: 'It is enabled and will inject into every new generation.',
        });
      }
      bus.emit('skills:changed');
      onOpenChange(false);
    } catch (err) {
      toast({
        title: skill ? 'Could not update skill' : 'Could not create skill',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85vh] overflow-y-auto scrollbar-slim sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{skill ? 'Edit skill' : 'New skill'}</DialogTitle>
          <DialogDescription>
            A named bundle of instructions PocketLLM can inject into its
            system prompt.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="skill-name">Name</Label>
            <Input
              id="skill-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={120}
              placeholder="e.g. Terraform reviewer"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="skill-description">Description</Label>
            <Input
              id="skill-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={300}
              placeholder="What this skill does (one line)"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="skill-instructions">Instructions</Label>
            <Textarea
              id="skill-instructions"
              value={instructions}
              onChange={(e) => setInstructions(e.target.value)}
              rows={10}
              className="font-mono text-[13px] leading-relaxed"
              placeholder={'When reviewing Terraform:\n- flag missing tags\n- suggest module extraction\n- …'}
              aria-describedby="skill-instructions-hint"
            />
            <p id="skill-instructions-hint" className="text-[11px] text-muted-foreground">
              The exact text injected into the system prompt when this skill
              is enabled.
            </p>
          </div>
        </div>

        <p className="flex items-start gap-2 rounded-lg bg-muted p-2.5 text-xs leading-relaxed text-muted-foreground">
          <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden />
          Active skills are injected into the system prompt on every
          generation.
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
            {skill ? 'Save changes' : 'Create skill'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
