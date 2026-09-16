/**
 * LogService — activity log, network audit, error log and usage
 * statistics. All local. Log retention is applied on boot.
 *
 * Privacy rules (from the plan):
 *  - Network audit never records prompt bodies.
 *  - Error log records safe messages + stack, never API keys,
 *    documents, prompt bodies or memory facts.
 */
import { bus } from '@/lib/core/events/event-bus';
import {
  activityRepo,
  errorRepo,
  networkAuditRepo,
  usageRepo,
} from '@/lib/core/db/repositories';
import type {
  ActivityEntry,
  ErrorEntry,
  NetworkAuditEntry,
  UsageDay,
} from '@/lib/types/domain';
import { settingsService } from './settings-service';
import { APP_VERSION, uuid } from '@/lib/utils';

type ActivityType = ActivityEntry['type'];

class LogService {
  private started = false;

  async start(): Promise<void> {
    if (this.started) return;
    this.started = true;
    await this.pruneLogs().catch(() => undefined);
  }

  /* -------------------------- activity -------------------------- */

  async recordActivity(type: ActivityType, label: string, meta?: ActivityEntry['meta']): Promise<void> {
    try {
      await activityRepo.put({ id: uuid(), ts: Date.now(), type, label, meta });
      bus.emit('activity:changed');
    } catch (err) {
      console.error('[log] activity write failed', err);
    }
  }

  async listActivity(): Promise<ActivityEntry[]> {
    const all = await activityRepo.getAll();
    return all.sort((a, b) => b.ts - a.ts);
  }

  /* ------------------------ network audit ------------------------ */

  async recordNetwork(entry: Omit<NetworkAuditEntry, 'id' | 'ts'>): Promise<void> {
    try {
      await networkAuditRepo.put({ id: uuid(), ts: Date.now(), ...entry });
      bus.emit('networkAudit:changed');
    } catch (err) {
      console.error('[log] network audit write failed', err);
    }
  }

  async listNetworkAudit(): Promise<NetworkAuditEntry[]> {
    const all = await networkAuditRepo.getAll();
    return all.sort((a, b) => b.ts - a.ts);
  }

  async clearNetworkAudit(): Promise<void> {
    await networkAuditRepo.clear();
    bus.emit('networkAudit:changed');
  }

  /* --------------------------- errors ---------------------------- */

  async recordError(feature: string, code: string, message: string, stack?: string): Promise<void> {
    try {
      await errorRepo.put({
        id: uuid(),
        ts: Date.now(),
        feature,
        code,
        // Keep messages bounded so a runaway loop can't fill storage.
        message: message.slice(0, 500),
        stack: stack?.slice(0, 2000),
        appVersion: APP_VERSION,
      });
      bus.emit('errors:changed');
    } catch (err) {
      console.error('[log] error write failed', err);
    }
  }

  async listErrors(): Promise<ErrorEntry[]> {
    const all = await errorRepo.getAll();
    return all.sort((a, b) => b.ts - a.ts);
  }

  async clearErrors(): Promise<void> {
    await errorRepo.clear();
    bus.emit('errors:changed');
  }

  /* --------------------------- usage ----------------------------- */

  private todayId(): string {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
      d.getDate()
    ).padStart(2, '0')}`;
  }

  async bumpUsage(patch: Partial<Omit<UsageDay, 'id'>>): Promise<void> {
    try {
      const id = this.todayId();
      const existing = await usageRepo.get(id);
      const day: UsageDay = existing ?? {
        id,
        generations: 0,
        cancellations: 0,
        tokensIn: 0,
        tokensOut: 0,
        chatsCreated: 0,
        documentsIndexed: 0,
      };
      for (const [k, v] of Object.entries(patch)) {
        if (typeof v === 'number') {
          (day as unknown as Record<string, number>)[k] =
            ((day as unknown as Record<string, number>)[k] ?? 0) + v;
        }
      }
      await usageRepo.put(day);
      bus.emit('usage:changed');
    } catch (err) {
      console.error('[log] usage write failed', err);
    }
  }

  async listUsage(): Promise<UsageDay[]> {
    const all = await usageRepo.getAll();
    return all.sort((a, b) => (a.id < b.id ? 1 : -1));
  }

  async clearUsage(): Promise<void> {
    await usageRepo.clear();
    bus.emit('usage:changed');
  }

  /* ------------------------- retention ---------------------------- */

  /** Drops log rows older than the retention window. */
  async pruneLogs(): Promise<void> {
    const days = settingsService.get().storage.logRetentionDays;
    if (days <= 0) return; // "Forever"
    const cutoff = Date.now() - days * 86_400_000;
    const prune = async (
      rows: { id: string; ts: number }[]
    ): Promise<number> => {
      const stale = rows.filter((r) => r.ts < cutoff).map((r) => r.id);
      if (stale.length) {
        // Destructive pruning is opt-in via days < 0? No — retention means it.
      }
      return stale.length;
    };
    // NOTE: full pruning requires reading all rows; keep it cheap and
    // guard against errors so boot never fails because of retention.
    void prune;
    const [activity, audit, errors] = await Promise.all([
      activityRepo.getAll(),
      networkAuditRepo.getAll(),
      errorRepo.getAll(),
    ]);
    const jobs: Promise<void>[] = [];
    jobs.push(
      activityRepo.deleteMany(
        activity.filter((r) => r.ts < cutoff).map((r) => r.id)
      )
    );
    jobs.push(
      networkAuditRepo.deleteMany(
        audit.filter((r) => r.ts < cutoff).map((r) => r.id)
      )
    );
    jobs.push(
      errorRepo.deleteMany(errors.filter((r) => r.ts < cutoff).map((r) => r.id))
    );
    await Promise.all(jobs);
  }
}

export const logService = new LogService();
