'use client';

/**
 * Backup — encrypted .pllm export/import. AES-256-GCM with
 * PBKDF2-HMAC-SHA256 (600,000 iterations), matching the app family.
 */
import { useRef, useState } from 'react';
import {
  CheckCircle2,
  Download,
  FileArchive,
  Loader2,
  ShieldCheck,
  Upload,
  XCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
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
import { Section } from '@/features/app/shared/ui';
import { backupService, WrongPasswordError, CorruptBackupError } from '@/lib/services/backup-service';
import type { BackupPayload } from '@/lib/types/domain';
import { bus } from '@/lib/core/events/event-bus';
import { toast } from '@/hooks/use-toast';
import { cn, formatNumber } from '@/lib/utils';

/* ---------------------------- password hint --------------------------- */

function passwordStrength(pw: string): { label: string; tone: string } {
  if (!pw) return { label: '', tone: '' };
  let score = 0;
  if (pw.length >= 8) score++;
  if (pw.length >= 14) score++;
  if (/[a-z]/.test(pw) && /[A-Z]/.test(pw)) score++;
  if (/\d/.test(pw)) score++;
  if (/[^A-Za-z0-9]/.test(pw)) score++;
  if (score <= 1) return { label: 'weak', tone: 'text-destructive' };
  if (score <= 3) return { label: 'fair', tone: 'text-warning' };
  return { label: 'strong', tone: 'text-success' };
}

/* -------------------------------- view -------------------------------- */

export function BackupSettings() {
  /* export */
  const [pass, setPass] = useState('');
  const [passConfirm, setPassConfirm] = useState('');
  const [exportError, setExportError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  /* import */
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [importPass, setImportPass] = useState('');
  const [validating, setValidating] = useState(false);
  const [summary, setSummary] = useState<Record<string, number> | null>(null);
  const [payload, setPayload] = useState<BackupPayload | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [restoring, setRestoring] = useState(false);

  const strength = passwordStrength(pass);

  const pickFile = (f: File | null) => {
    setFile(f);
    setSummary(null);
    setPayload(null);
    setImportPass('');
  };

  const runExport = async () => {
    setExportError(null);
    if (pass.length < 8) {
      setExportError('Password must be at least 8 characters.');
      return;
    }
    if (pass !== passConfirm) {
      setExportError("Passwords don't match.");
      return;
    }
    setExporting(true);
    try {
      await backupService.export(pass);
      toast({
        title: 'Backup exported',
        description: 'Encrypted .pllm file downloaded. Keep the password safe — it cannot be recovered.',
      });
      setPass('');
      setPassConfirm('');
    } catch (err) {
      toast({
        title: 'Export failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setExporting(false);
    }
  };

  const runValidate = async () => {
    if (!file || !importPass) return;
    setValidating(true);
    setSummary(null);
    setPayload(null);
    try {
      const result = await backupService.validate(file, importPass);
      setSummary(result.summary);
      setPayload(result.payload);
    } catch (err) {
      if (err instanceof WrongPasswordError) {
        toast({
          title: 'Wrong password or the file was tampered with',
          description: 'Decryption failed — nothing was changed.',
          variant: 'destructive',
        });
      } else if (err instanceof CorruptBackupError) {
        toast({
          title: 'Not a valid backup',
          description: err.message,
          variant: 'destructive',
        });
      } else {
        toast({
          title: 'Validation failed',
          description: err instanceof Error ? err.message : String(err),
          variant: 'destructive',
        });
      }
    } finally {
      setValidating(false);
    }
  };

  const runRestore = async () => {
    if (!payload) return;
    setRestoring(true);
    try {
      await backupService.restore(payload);
      bus.emit('chats:changed');
      bus.emit('messages:changed', { chatId: '' });
      bus.emit('personas:changed');
      bus.emit('prompts:changed');
      bus.emit('skills:changed');
      bus.emit('tags:changed');
      bus.emit('notes:changed');
      bus.emit('memories:changed');
      bus.emit('documents:changed', {});
      bus.emit('transcripts:changed');
      bus.emit('labRuns:changed');
      toast({
        title: 'Backup restored',
        description: 'Merged by id — on collisions, the incoming copy wins. Nothing was deleted.',
      });
      pickFile(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
      setConfirmOpen(false);
    } catch (err) {
      toast({
        title: 'Restore failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
      setConfirmOpen(false);
    } finally {
      setRestoring(false);
    }
  };

  const summaryEntries: Array<[string, string, number]> = summary
    ? [
        ['Chats', 'chats', summary.chats],
        ['Messages', 'messages', summary.messages],
        ['Personas', 'personas', summary.personas],
        ['Prompts', 'prompts', summary.prompts],
        ['Skills', 'skills', summary.skills],
        ['Memories', 'memories', summary.memories],
        ['Documents', 'documents', summary.documents],
        ['Notes', 'notes', summary.notes],
        ['Transcripts', 'transcripts', summary.transcripts],
        ['Saved searches', 'savedSearches', summary.savedSearches],
      ]
    : [];

  return (
    <div className="space-y-6">
      {/* ------------------------------ export ------------------------------ */}
      <Section
        title="Export"
        description="Encrypt everything — chats, messages, personas, prompts, skills, tags, notes, memories, documents, transcripts, lab runs, saved searches — into one .pllm file."
      >
        <div className="space-y-3.5">
          <div>
            <Label htmlFor="backup-pass" className="text-sm font-medium">
              Password
            </Label>
            <Input
              id="backup-pass"
              type="password"
              value={pass}
              onChange={(e) => setPass(e.target.value)}
              autoComplete="new-password"
              placeholder="At least 8 characters"
              className="mt-1.5 w-full sm:w-[320px]"
            />
            {strength.label && (
              <p className={cn('mt-1 text-xs', strength.tone)} aria-live="polite">
                Strength: {strength.label}
              </p>
            )}
          </div>
          <div>
            <Label htmlFor="backup-pass-confirm" className="text-sm font-medium">
              Confirm password
            </Label>
            <Input
              id="backup-pass-confirm"
              type="password"
              value={passConfirm}
              onChange={(e) => setPassConfirm(e.target.value)}
              autoComplete="new-password"
              className="mt-1.5 w-full sm:w-[320px]"
            />
          </div>
          {exportError && (
            <p className="text-xs text-destructive" role="alert">
              {exportError}
            </p>
          )}
          <Button onClick={() => void runExport()} disabled={exporting || !pass || !passConfirm}>
            {exporting ? (
              <Loader2 className="animate-spin" aria-hidden />
            ) : (
              <Download aria-hidden />
            )}
            Export encrypted backup
          </Button>
          <p className="flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
            <ShieldCheck className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden />
            AES-256-GCM · PBKDF2 600,000 iterations · .pllm format. There is no
            password recovery — a lost password means an unreadable file.
          </p>
        </div>
      </Section>

      {/* ------------------------------ import ------------------------------ */}
      <Section
        title="Import"
        description="Validate first — the archive is decrypted in memory and nothing touches your data until you confirm the restore."
      >
        <div className="space-y-3.5">
          <div>
            <Label htmlFor="backup-file" className="text-sm font-medium">
              Backup file
            </Label>
            <input
              ref={fileInputRef}
              id="backup-file"
              type="file"
              accept=".pllm,application/octet-stream"
              className="sr-only"
              onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
            />
            <div className="mt-1.5 flex flex-wrap items-center gap-2">
              <Button
                variant="outline"
                onClick={() => fileInputRef.current?.click()}
                aria-label="Choose .pllm backup file"
              >
                <FileArchive aria-hidden />
                Choose .pllm file
              </Button>
              {file && (
                <span className="max-w-full truncate font-mono text-xs text-muted-foreground">
                  {file.name} · {Math.max(1, Math.round(file.size / 1024))} KB
                </span>
              )}
            </div>
          </div>
          <div>
            <Label htmlFor="backup-import-pass" className="text-sm font-medium">
              Password
            </Label>
            <Input
              id="backup-import-pass"
              type="password"
              value={importPass}
              onChange={(e) => setImportPass(e.target.value)}
              autoComplete="off"
              className="mt-1.5 w-full sm:w-[320px]"
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              onClick={() => void runValidate()}
              disabled={!file || !importPass || validating}
            >
              {validating ? (
                <Loader2 className="animate-spin" aria-hidden />
              ) : (
                <Upload aria-hidden />
              )}
              Validate
            </Button>
            {payload && summary && (
              <Button
                variant="default"
                onClick={() => setConfirmOpen(true)}
                disabled={restoring}
              >
                Restore backup
              </Button>
            )}
          </div>

          {payload && summary && (
            <div className="rounded-xl border border-success/40 bg-success/10 p-4" role="status">
              <p className="flex items-center gap-2 text-[13px] font-medium">
                <CheckCircle2 className="h-4 w-4 shrink-0 text-success" aria-hidden />
                Decrypted successfully — here&apos;s what&apos;s inside:
              </p>
              <dl className="mt-3 grid grid-cols-2 gap-x-6 gap-y-1.5 sm:grid-cols-3">
                {summaryEntries.map(([label, key, count]) => (
                  <div key={key} className="flex items-baseline justify-between gap-2">
                    <dt className="text-xs text-muted-foreground">{label}</dt>
                    <dd className="font-mono text-xs">{formatNumber(count)}</dd>
                  </div>
                ))}
              </dl>
            </div>
          )}

          <p className="flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
            <XCircle className="mt-0.5 h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden />
            Restore merges by id — on collision, the incoming copy wins; it never
            deletes what you already have. Storage quotas and the .pllm archive
            do not include model files — re-download those from Models.
          </p>
        </div>
      </Section>

      {/* --------------------------- restore confirm ------------------------ */}
      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Restore this backup?</AlertDialogTitle>
            <AlertDialogDescription>
              Everything listed above will be written into this browser.
              Existing items with the same id are replaced by the incoming
              copy; nothing is deleted. This cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Not now</AlertDialogCancel>
            <AlertDialogAction
              onClick={(e) => {
                e.preventDefault(); // keep the dialog open until it settles
                void runRestore();
              }}
            >
              {restoring ? <Loader2 className="animate-spin" aria-hidden /> : null}
              Restore backup
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
