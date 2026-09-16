'use client';

/**
 * SkillCard — one skill bundle.
 *
 * The enable switch persists immediately (optimistic UI + repo write +
 * 'skills:changed'), edit and delete sit next to it. The source badge
 * shows where the skill came from, with a link for GitHub imports.
 */
import { ExternalLink, Pencil, Trash2 } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { formatRelativeTime } from '@/lib/utils';
import type { Skill } from '@/lib/types/domain';

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/** Shortens a URL for display: keeps host + a trimmed path. */
function shortUrl(url: string): string {
  try {
    const parsed = new URL(url);
    const path = parsed.pathname.replace(/\/$/, '');
    if (path.length <= 24) return `${parsed.host}${path}`;
    return `${parsed.host}${path.slice(0, 23)}…`;
  } catch {
    return url;
  }
}

export function SkillCard({
  skill,
  onToggle,
  onEdit,
  onDelete,
}: {
  skill: Skill;
  onToggle: (skill: Skill, enabled: boolean) => void;
  onEdit: (skill: Skill) => void;
  onDelete: (skill: Skill) => void;
}) {
  const nameLabel = truncate(skill.name, 48);

  return (
    <li className="rounded-xl border border-border bg-card p-4">
      <div className="flex flex-wrap items-start justify-between gap-x-3 gap-y-2">
        <div className="min-w-0 flex-1 basis-52">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-sm font-medium leading-snug">{skill.name}</h3>
            <Badge
              variant="outline"
              className="px-1.5 py-0 text-[11px] font-medium"
            >
              {skill.source === 'github' ? 'GitHub' : 'Local'}
            </Badge>
          </div>
          <p className="mt-1 line-clamp-2 text-[13px] leading-relaxed text-muted-foreground">
            {skill.description || 'No description.'}
          </p>
          <p className="mt-1.5 text-[11px] text-muted-foreground">
            updated {formatRelativeTime(skill.updatedAt)}
          </p>
        </div>

        <div className="flex shrink-0 items-center gap-2.5">
          <div className="flex items-center gap-1.5">
            <Switch
              checked={skill.enabled}
              onCheckedChange={(enabled) => onToggle(skill, enabled)}
              aria-label={`${skill.enabled ? 'Disable' : 'Enable'} skill ${nameLabel}`}
            />
            <span
              className="text-[11px] text-muted-foreground"
              aria-hidden
            >
              {skill.enabled ? 'on' : 'off'}
            </span>
          </div>
          <div className="flex items-center gap-0.5">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => onEdit(skill)}
              aria-label={`Edit skill ${nameLabel}`}
              title="Edit skill"
            >
              <Pencil aria-hidden />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="text-muted-foreground hover:text-destructive"
              onClick={() => onDelete(skill)}
              aria-label={`Delete skill ${nameLabel}`}
              title="Delete skill"
            >
              <Trash2 aria-hidden />
            </Button>
          </div>
        </div>
      </div>

      <div className="mt-3 border-t border-border pt-2.5">
        {skill.source === 'github' && skill.sourceUrl ? (
          <a
            href={skill.sourceUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex max-w-full items-center gap-1 text-[11px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-card rounded-sm"
          >
            <ExternalLink className="h-3 w-3 shrink-0" aria-hidden />
            <span className="truncate">{shortUrl(skill.sourceUrl)}</span>
            <span className="sr-only">(opens in a new tab)</span>
          </a>
        ) : (
          <span className="text-[11px] text-muted-foreground">
            Created locally
          </span>
        )}
      </div>
    </li>
  );
}
