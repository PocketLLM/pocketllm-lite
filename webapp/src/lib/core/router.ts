/**
 * HashRouter — client-side routing for the single-page app.
 *
 * Marketing lives at `#/` (or any non-/app hash); the application
 * lives under `#/app/...`. Using the hash keeps the whole product on
 * one origin with zero server routes, which also keeps localStorage
 * and IndexedDB stable.
 */

export interface Route {
  /** True when the marketing site should render. */
  isMarketing: boolean;
  /** Path after `#`, normalized to start with "/" (e.g. "/app/chat/x"). */
  path: string;
  /** Segments after "/app": ["chat", "abc"]. */
  appSegments: string[];
}

function parseHash(hash: string): Route {
  let path = hash.replace(/^#/, '');
  if (!path.startsWith('/')) {
    // Marketing anchors like #features — not an app route.
    return { isMarketing: true, path: `/${path}`, appSegments: [] };
  }
  if (path === '/app' || path.startsWith('/app/')) {
    const rest = path.slice('/app'.length).replace(/^\//, '');
    const appSegments = rest.split('/').filter(Boolean);
    return { isMarketing: false, path, appSegments };
  }
  return { isMarketing: true, path, appSegments: [] };
}

class HashRouter {
  private listeners = new Set<(route: Route) => void>();
  private current: Route | null = null;

  get route(): Route {
    if (this.current) return this.current;
    if (typeof window === 'undefined') {
      return { isMarketing: true, path: '/', appSegments: [] };
    }
    this.current = parseHash(window.location.hash);
    return this.current;
  }

  start(): () => void {
    if (typeof window === 'undefined') return () => undefined;
    const onChange = () => {
      this.current = parseHash(window.location.hash);
      for (const fn of this.listeners) fn(this.current!);
    };
    window.addEventListener('hashchange', onChange);
    onChange();
    return () => window.removeEventListener('hashchange', onChange);
  }

  subscribe(fn: (route: Route) => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  /** Navigate to an app path like "/app/chat/123". */
  navigate(path: string, opts?: { replace?: boolean }): void {
    const hash = path.startsWith('/') ? `#${path}` : `#/${path}`;
    if (window.location.hash === hash) return;
    if (opts?.replace) {
      history.replaceState(null, '', hash);
      window.dispatchEvent(new HashChangeEvent('hashchange'));
    } else {
      window.location.hash = hash;
    }
  }

  /** Navigate to a marketing anchor (scrolls to the element). */
  navigateAnchor(anchor: string): void {
    const el = document.getElementById(anchor);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }
}

export const router = new HashRouter();
