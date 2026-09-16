/**
 * Generic OOP repository over IndexedDB.
 *
 * Every entity (chats, messages, memories, …) gets a `Repository<T>`
 * with CRUD + query helpers. The repository is the ONLY layer allowed
 * to touch IndexedDB; services sit on top.
 */
import { openDatabase, withStores, type StoreName } from './idb';
import type { UUID } from '@/lib/types/domain';

export class Repository<T extends { id: UUID }> {
  constructor(private readonly store: StoreName) {}

  private static dbPromise: Promise<IDBDatabase> | null = null;

  /** Shared, lazily-opened database handle (one per tab). */
  static database(): Promise<IDBDatabase> {
    if (!Repository.dbPromise) {
      Repository.dbPromise = openDatabase();
    }
    return Repository.dbPromise;
  }

  private db(): Promise<IDBDatabase> {
    return Repository.database();
  }

  async get(id: UUID): Promise<T | undefined> {
    const db = await this.db();
    return withStores(db, this.store, 'readonly', (tx) => {
      const req = tx.objectStore(this.store).get(id);
      return new Promise<T | undefined>((resolve, reject) => {
        req.onsuccess = () => resolve(req.result as T | undefined);
        req.onerror = () => reject(req.error);
      });
    });
  }

  async getAll(): Promise<T[]> {
    const db = await this.db();
    return withStores(db, this.store, 'readonly', (tx) => {
      const req = tx.objectStore(this.store).getAll();
      return new Promise<T[]>((resolve, reject) => {
        req.onsuccess = () => resolve(req.result as T[]);
        req.onerror = () => reject(req.error);
      });
    });
  }

  async getByIndex(indexName: string, key: IDBValidKey): Promise<T[]> {
    const db = await this.db();
    return withStores(db, this.store, 'readonly', (tx) => {
      const req = tx.objectStore(this.store).index(indexName).getAll(key);
      return new Promise<T[]>((resolve, reject) => {
        req.onsuccess = () => resolve(req.result as T[]);
        req.onerror = () => reject(req.error);
      });
    });
  }

  async put(record: T): Promise<T> {
    const db = await this.db();
    await withStores(db, this.store, 'readwrite', (tx) => {
      tx.objectStore(this.store).put(record);
    });
    return record;
  }

  async putAll(records: T[]): Promise<void> {
    if (records.length === 0) return;
    const db = await this.db();
    await withStores(db, this.store, 'readwrite', (tx) => {
      const os = tx.objectStore(this.store);
      for (const r of records) os.put(r);
    });
  }

  async delete(id: UUID): Promise<void> {
    const db = await this.db();
    await withStores(db, this.store, 'readwrite', (tx) => {
      tx.objectStore(this.store).delete(id);
    });
  }

  async deleteMany(ids: UUID[]): Promise<void> {
    if (ids.length === 0) return;
    const db = await this.db();
    await withStores(db, this.store, 'readwrite', (tx) => {
      const os = tx.objectStore(this.store);
      for (const id of ids) os.delete(id);
    });
  }

  async clear(): Promise<void> {
    const db = await this.db();
    await withStores(db, this.store, 'readwrite', (tx) => {
      tx.objectStore(this.store).clear();
    });
  }

  async count(): Promise<number> {
    const db = await this.db();
    return withStores(db, this.store, 'readonly', (tx) => {
      const req = tx.objectStore(this.store).count();
      return new Promise<number>((resolve, reject) => {
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
    });
  }
}
