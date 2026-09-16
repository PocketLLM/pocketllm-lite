/**
 * Typed pub/sub event bus (browser-safe, zero dependencies).
 * Services publish domain events; React stores subscribe and refresh.
 * This keeps the OOP layer decoupled from React entirely.
 */

export interface DomainEvents {
  'chats:changed': void;
  'messages:changed': { chatId: string };
  'branches:changed': { chatId: string };
  'personas:changed': void;
  'prompts:changed': void;
  'skills:changed': void;
  'tags:changed': void;
  'notes:changed': void;
  'memories:changed': void;
  /** Fired when the pipeline auto-extracts memories after a turn. */
  'memories:extracted': { chatId: string; count: number; facts: string[] };
  'documents:changed': { documentId?: string };
  'providers:changed': void;
  'models:changed': void;
  'downloads:changed': void;
  'toolEvents:changed': void;
  'networkAudit:changed': void;
  'activity:changed': void;
  'errors:changed': void;
  'labRuns:changed': void;
  'transcripts:changed': void;
  'settings:changed': void;
  'usage:changed': void;
}

type EventKey = keyof DomainEvents;
type Handler<K extends EventKey> = DomainEvents[K] extends void
  ? () => void
  : (payload: DomainEvents[K]) => void;

class TypedEventBus {
  private handlers = new Map<EventKey, Set<(payload: unknown) => void>>();

  /** Subscribe; returns an unsubscribe function. */
  on<K extends EventKey>(event: K, handler: Handler<K>): () => void {
    let set = this.handlers.get(event);
    if (!set) {
      set = new Set();
      this.handlers.set(event, set);
    }
    set.add(handler as (payload: unknown) => void);
    return () => set!.delete(handler as (payload: unknown) => void);
  }

  off<K extends EventKey>(event: K, handler: Handler<K>): void {
    this.handlers.get(event)?.delete(handler as (payload: unknown) => void);
  }

  emit<K extends EventKey>(
    event: K,
    ...args: DomainEvents[K] extends void ? [] : [DomainEvents[K]]
  ): void {
    const set = this.handlers.get(event);
    if (!set) return;
    const payload = (args as unknown[])[0];
    for (const h of [...set]) {
      try {
        h(payload);
      } catch (err) {
        // A broken listener must never break the emitter.
        console.error('[event-bus] handler error', err);
      }
    }
  }
}

/** Global bus — imported by services and stores. */
export const bus = new TypedEventBus();
