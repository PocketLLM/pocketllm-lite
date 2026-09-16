'use client';

/**
 * ImportSkillDialog — import a skill from a URL.
 *
 * Fetches through the network gateway (purpose 'github-skill') so the
 * request is policy-checked and audited, parses the markdown with a
 * simple, honest heuristic (first # heading = name, first paragraph =
 * description, rest = instructions) and stores it as a GitHub-sourced
 * skill. Failures are surfaced verbatim — blocked, HTML page, empty
 * file, network error.
 */
import { useEffect, useState } from 'react';
import { Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
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
import { gateway } from '@/lib/core/net/network-gateway';
import { skillRepo } from '@/lib/core/db/repositories';
import { uuid } from '@/lib/utils';
import type { Skill } from '@/lib/types/domain';

const MAX_SKILL_BYTES = 200_000;

/** Derives a readable name from the last path segment of a URL. */
function filenameFromUrl(url: string): string {
  try {
    const last = new URL(url).pathname.split('/').filter(Boolean).pop() ?? '';
    const stem = last.replace(/\.[^.]+$/, '');
    return decodeURIComponent(stem).trim().slice(0, 120) || 'Imported skill';
  } catch {
    return 'Imported skill';
  }
}

/**
 * Parses a skill markdown document:
 * first `# Heading` → name, first paragraph after it → description,
 * everything after that paragraph → instructions. When no heading
 * exists, falls back to the URL filename as the name.
 */
export function parseSkillMarkdown(
  markdown: string,
  url: string
): { name: string; description: string; instructions: string } {
  const lines = markdown.split(/\r?\n/);

  const firstParagraphAfter = (start: number): { text: string; end: number } => {
    let i = start;
    while (i < lines.length && !lines[i].trim()) i++;
    const from = i;
    const para: string[] = [];
    while (i < lines.length && lines[i].trim()) {
      para.push(lines[i].trim());
      i++;
    }
    return { text: para.join(' '), end: i };
  };

  const headingIdx = lines.findIndex((l) => /^#\s+\S/.test(l));

  let name: string;
  let paragraph: { text: string; end: number };

  if (headingIdx === -1) {
    // Parsing failed — default the name to the file name.
    name = filenameFromUrl(url);
    paragraph = firstParagraphAfter(0);
  } else {
    name = lines[headingIdx].replace(/^#\s+/, '').trim();
    paragraph = firstParagraphAfter(headingIdx + 1);
  }

  const instructions = lines.slice(paragraph.end).join('\n').trim();

  return {
    name: (name || filenameFromUrl(url)).slice(0, 120),
    description: paragraph.text.slice(0, 300),
    instructions,
  };
}

export function ImportSkillDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const [url, setUrl] = useState('');
  const [importing, setImporting] = useState(false);

  useEffect(() => {
    if (open) {
      setUrl('');
      setImporting(false);
    }
  }, [open]);

  const handleImport = async () => {
    const trimmed = url.trim();
    let parsedUrl: URL;
    try {
      parsedUrl = new URL(trimmed);
    } catch {
      toast({
        title: 'Import failed',
        description: 'That does not look like a valid URL.',
        variant: 'destructive',
      });
      return;
    }
    if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') {
      toast({
        title: 'Import failed',
        description: 'Only http(s) URLs can be imported as skills.',
        variant: 'destructive',
      });
      return;
    }

    setImporting(true);
    try {
      const res = await gateway.request('github-skill', trimmed);
      if (!res.ok) {
        throw new Error(`The URL responded with HTTP ${res.status}.`);
      }
      const contentType = res.headers.get('content-type') ?? '';
      const text = await res.text();
      if (!text.trim()) {
        throw new Error('The file is empty.');
      }
      if (/text\/html/i.test(contentType)) {
        throw new Error(
          'That URL returned an HTML page, not a markdown file. Use the raw file URL (for example raw.githubusercontent.com/…).'
        );
      }
      if (text.length > MAX_SKILL_BYTES) {
        throw new Error('The file is too large to import as a skill.');
      }

      const parsed = parseSkillMarkdown(text, trimmed);
      const now = Date.now();
      const skill: Skill = {
        id: uuid(),
        name: parsed.name,
        description: parsed.description,
        instructions: parsed.instructions,
        source: 'github',
        sourceUrl: trimmed,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      };
      await skillRepo.put(skill);
      bus.emit('skills:changed');
      toast({
        title: 'Skill imported',
        description: `“${parsed.name.slice(0, 60)}” is enabled and will inject into new generations.`,
      });
      onOpenChange(false);
    } catch (err) {
      toast({
        title: 'Import failed',
        description:
          err instanceof Error
            ? err.message
            : 'The request failed — check the URL and your network policy.',
        variant: 'destructive',
      });
    } finally {
      setImporting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Import skill from URL</DialogTitle>
          <DialogDescription>
            Paste the raw markdown URL of a skill (for example a
            raw.githubusercontent.com link). PocketLLM reads its first
            heading as the name, the first paragraph as the description and
            the rest as the instructions.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-2">
          <Label htmlFor="skill-url">URL</Label>
          <Input
            id="skill-url"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="https://raw.githubusercontent.com/user/repo/main/skill.md"
            inputMode="url"
            autoComplete="off"
            spellCheck={false}
          />
          <p className="text-[11px] leading-relaxed text-muted-foreground">
            The fetch goes through the network gateway — it is blocked in
            Strict Offline mode and recorded in the network audit log.
          </p>
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={importing}
          >
            Cancel
          </Button>
          <Button
            onClick={() => void handleImport()}
            disabled={!url.trim() || importing}
          >
            {importing && <Loader2 className="animate-spin" aria-hidden />}
            Import skill
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
