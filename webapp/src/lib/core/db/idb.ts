/**
 * Low-level IndexedDB promise wrapper.
 *
 * A tiny, dependency-free foundation for the OOP repository layer.
 * Every database operation in PocketLLM flows through here so that
 * storage behavior (quota errors, missing stores, upgrades) can be
 * handled uniformly.
 */

const DB_NAME = 'pocketllm';
const DB_VERSION = 1;

/** All object stores created at schema version 1. */
export const STORES = [
  'chats',
  'messages',
  'branches',
  'personas',
  'prompts',
  'skills',
  'tags',
  'notes',
  'memories',
  'documents',
  'chunks',
  'providers',
  'models',
  'downloads',
  'toolEvents',
  'networkAudit',
  'activityLog',
  'errorLog',
  'labRuns',
  'transcripts',
  'usage',
] as const;

export type StoreName = (typeof STORES)[number];

function reqToPromise<T>(req: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

/** Opens (and lazily upgrades) the PocketLLM database. */
export function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      // Fresh install of every store. KeyPath is always "id".
      for (const store of STORES) {
        if (!db.objectStoreNames.contains(store)) {
          const os = db.createObjectStore(store, { keyPath: 'id' });
          // Secondary indexes used by the query layer.
          switch (store) {
            case 'messages':
              os.createIndex('chatId', 'chatId', { unique: false });
              os.createIndex('chatId_seq', ['chatId', 'seq'], { unique: false });
              break;
            case 'branches':
              os.createIndex('chatId', 'chatId', { unique: false });
              break;
            case 'chunks':
              os.createIndex('documentId', 'documentId', { unique: false });
              break;
            case 'toolEvents':
              os.createIndex('chatId', 'chatId', { unique: false });
              break;
          }
        }
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

/** Runs a transaction on the given stores and resolves with its result. */
export async function withStores<T>(
  db: IDBDatabase,
  stores: StoreName | StoreName[],
  mode: IDBTransactionMode,
  fn: (tx: IDBTransaction) => Promise<T> | T
): Promise<T> {
  const storeList = Array.isArray(stores) ? stores : [stores];
  return new Promise<T>((resolve, reject) => {
    const tx = db.transaction(storeList, mode);
    let result: T;
    let failed = false;
    tx.oncomplete = () => resolve(result);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error ?? new Error('Transaction aborted'));
    Promise.resolve(fn(tx)).then(
      (r) => {
        result = r;
      },
      (err) => {
        failed = true;
        try {
          tx.abort();
        } catch {
          /* already aborted */
        }
        reject(err);
      }
    );
    void failed;
  });
}

export { reqToPromise };
