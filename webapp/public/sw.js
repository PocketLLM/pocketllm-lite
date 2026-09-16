/**
 * PocketLLM service worker — network-first passthrough.
 *
 * Purpose: satisfies PWA installability without ever serving stale
 * application code in development. Static app shell assets get a
 * cache-first fallback for offline reloads; everything else always
 * goes to the network first (local-first data lives in IndexedDB
 * and OPFS, never in this cache).
 *
 * Dev safety: when served from a local dev server (localhost/127.0.0.1),
 * the worker stays a pure passthrough — no caching at all. Dev chunks
 * change on every edit and a cached broken chunk would poison every
 * reload until manually purged.
 */
const CACHE = 'pocketllm-shell-v2';
const SHELL = ['/', '/logo.png', '/manifest.json'];

/** True when running under a local dev server. */
const IS_DEV =
  self.location.hostname === 'localhost' ||
  self.location.hostname === '127.0.0.1';

self.addEventListener('install', (event) => {
  if (IS_DEV) {
    // Dev: nothing to prime; take over immediately.
    self.skipWaiting();
    return;
  }
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(SHELL)).catch(() => undefined)
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            // Purge every cache from older versions (and any dev-era cache).
            .filter((k) => k !== CACHE || IS_DEV)
            .map((k) => caches.delete(k))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (IS_DEV) return; // pure passthrough in development

  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Network-first with cache fallback for same-origin GETs.
  event.respondWith(
    fetch(request)
      .then((response) => {
        // Cache successful basic responses for the offline fallback.
        if (response.ok && response.type === 'basic') {
          const clone = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, clone)).catch(() => undefined);
        }
        return response;
      })
      .catch(() =>
        caches.match(request).then((cached) => cached ?? caches.match('/'))
      )
  );
});
