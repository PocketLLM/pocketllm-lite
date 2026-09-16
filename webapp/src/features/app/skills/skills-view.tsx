'use client';

/**
 * SkillsView — standing instruction bundles.
 *
 * Route: #/app/skills
 * Skills are injected into the system prompt of every generation while
 * enabled. Create locally, import from a raw markdown URL (through
 * the network gateway), toggle instantly, edit and delete. Deleting a
 * skill never breaks existing chats — it just stops injecting.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Download, Package, Plus } from 'lucide-react';
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
import { EmptyState, PageHeader } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { skillRepo } from '@/lib/core/db/repositories';
import type { Skill } from '@/lib/types/domain';
import { ImportSkillDialog } from './import-skill-dialog';
import { SkillCard } from './skill-card';
import { SkillDialog } from './skill-dialog';

export function SkillsView() {
  const [skills, setSkills] = useState<Skill[] | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Skill | null>(null);
  const [importOpen, setImportOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Skill | null>(null);
  const [deleting, setDeleting] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const all = await skillRepo.getAll();
      setSkills(all.sort((a, b) => b.updatedAt - a.updatedAt));
    } catch (err) {
      setSkills([]);
      toast({
        title: 'Could not load skills',
        description:
          err instanceof Error
            ? err.message
            : 'Local storage is unavailable in this session.',
        variant: 'destructive',
      });
    }
  }, []);

  useEffect(() => {
    void refresh();
    const unsub = bus.on('skills:changed', () => void refresh());
    return () => {
      unsub();
    };
  }, [refresh]);

  const enabledCount = useMemo(
    () => (skills ?? []).filter((s) => s.enabled).length,
    [skills]
  );

  const openNew = useCallback(() => {
    setEditTarget(null);
    setDialogOpen(true);
  }, []);

  const openEdit = useCallback((skill: Skill) => {
    setEditTarget(skill);
    setDialogOpen(true);
  }, []);

  const handleToggle = useCallback(
    async (skill: Skill, enabled: boolean) => {
      // Optimistic flip; the bus refresh reconciles after the write.
      setSkills(
        (prev) =>
          prev?.map((s) => (s.id === skill.id ? { ...s, enabled } : s)) ?? prev
      );
      try {
        await skillRepo.put({ ...skill, enabled, updatedAt: Date.now() });
        bus.emit('skills:changed');
      } catch (err) {
        toast({
          title: 'Could not update skill',
          description: err instanceof Error ? err.message : 'Try again.',
          variant: 'destructive',
        });
        void refresh();
      }
    },
    [refresh]
  );

  const handleDelete = useCallback(async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await skillRepo.delete(deleteTarget.id);
      bus.emit('skills:changed');
      toast({
        title: 'Skill deleted',
        description: `“${deleteTarget.name}” will no longer be injected. Existing chats keep working.`,
      });
      setDeleteTarget(null);
    } catch (err) {
      toast({
        title: 'Could not delete skill',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setDeleting(false);
    }
  }, [deleteTarget]);

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-24 pt-6 sm:px-6 sm:pt-8">
        <PageHeader
          title="Skills"
          description="Bundles of instructions injected into every chat where enabled."
          actions={
            <>
              <Button variant="outline" onClick={() => setImportOpen(true)}>
                <Download aria-hidden />
                Import from URL
              </Button>
              <Button onClick={openNew}>
                <Plus aria-hidden />
                New skill
              </Button>
            </>
          }
        />

        {skills === null ? (
          <div className="space-y-3" aria-hidden>
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-32 rounded-xl" />
            ))}
          </div>
        ) : skills.length === 0 ? (
          <div className="mt-4">
            <EmptyState
              icon={Package}
              title="No skills yet"
              description="Skills are bundles of instructions injected into every chat while enabled. Personas change how the assistant behaves in one chat; prompts are one-off message starters; skills add standing instructions across all chats."
              action={
                <div className="flex flex-wrap justify-center gap-2">
                  <Button onClick={openNew}>
                    <Plus aria-hidden />
                    New skill
                  </Button>
                  <Button variant="outline" onClick={() => setImportOpen(true)}>
                    <Download aria-hidden />
                    Import from URL
                  </Button>
                </div>
              }
            />
          </div>
        ) : (
          <section aria-labelledby="skills-heading">
            <div className="mb-3 flex items-center justify-between">
              <h2
                id="skills-heading"
                className="text-sm font-semibold text-muted-foreground"
              >
                Skills
              </h2>
              <span className="text-[11px] tabular-nums text-muted-foreground">
                {enabledCount} of {skills.length} enabled
              </span>
            </div>
            <ul className="space-y-3">
              {skills.map((skill) => (
                <SkillCard
                  key={skill.id}
                  skill={skill}
                  onToggle={(s, enabled) => void handleToggle(s, enabled)}
                  onEdit={openEdit}
                  onDelete={setDeleteTarget}
                />
              ))}
            </ul>
          </section>
        )}
      </div>

      <SkillDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        skill={dialogOpen ? editTarget : null}
      />

      <ImportSkillDialog open={importOpen} onOpenChange={setImportOpen} />

      <AlertDialog
        open={!!deleteTarget}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete skill?</AlertDialogTitle>
            <AlertDialogDescription>
              “{deleteTarget?.name}” will stop being injected into new
              generations. Existing chats keep working — the skill just stops
              injecting.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-white hover:bg-destructive/90 dark:bg-destructive/60"
              disabled={deleting}
              onClick={(e) => {
                // Keep the dialog open until the delete settles.
                e.preventDefault();
                void handleDelete();
              }}
            >
              Delete skill
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
