/**
 * SearchService — web search for the `web_search` tool.
 *
 * Runs entirely in the browser through the NetworkGateway (so Strict
 * Offline, auditing and the per-purpose policy apply):
 *  - With a Tavily API key (the user's own) → Tavily search.
 *  - Without one → Wikipedia's public, CORS-enabled search API. It is
 *    keyless and honest about being an encyclopedia, not the open web.
 *
 * The Tavily key is held in sessionStorage by default; the user can opt
 * in to keeping it in this browser's localStorage. It is never written
 * to backups, logs or IndexedDB.
 */
import { gateway } from '@/lib/core/net/network-gateway';

export interface SearchResult {
  name: string;
  url: string;
  snippet: string;
}

export interface SearchResponse {
  provider: 'tavily' | 'wikipedia';
  results: SearchResult[];
}

const KEY_NAME = 'pocketllm.tavilyKey';

/** Where the Tavily key currently lives. */
export type KeyStorage = 'session' | 'device' | 'none';

export const searchKeyStore = {
  get(): string {
    try {
      return sessionStorage.getItem(KEY_NAME) ?? localStorage.getItem(KEY_NAME) ?? '';
    } catch {
      return '';
    }
  },

  where(): KeyStorage {
    try {
      if (sessionStorage.getItem(KEY_NAME)) return 'session';
      if (localStorage.getItem(KEY_NAME)) return 'device';
    } catch {
      /* storage blocked */
    }
    return 'none';
  },

  /** Saves the key; `persist` keeps it across browser restarts. */
  set(key: string, persist: boolean): void {
    this.clear();
    const trimmed = key.trim();
    if (!trimmed) return;
    try {
      (persist ? localStorage : sessionStorage).setItem(KEY_NAME, trimmed);
    } catch {
      /* storage blocked — key stays unset */
    }
  },

  clear(): void {
    try {
      sessionStorage.removeItem(KEY_NAME);
      localStorage.removeItem(KEY_NAME);
    } catch {
      /* storage blocked */
    }
  },
};

/** Removes the highlight markup Wikipedia puts in snippets. */
function stripHtml(html: string): string {
  return html
    .replace(/<[^>]+>/g, '')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&#039;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
}

async function searchTavily(query: string, apiKey: string): Promise<SearchResult[]> {
  const res = await gateway.request('web-search', 'https://api.tavily.com/search', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({ query, max_results: 6, search_depth: 'basic' }),
    signal: AbortSignal.timeout(15_000),
  });
  if (res.status === 401 || res.status === 403) {
    throw new Error('Tavily rejected the API key. Check it in Settings → Tools.');
  }
  if (!res.ok) throw new Error(`Tavily search failed (HTTP ${res.status})`);
  const json = (await res.json()) as {
    results?: Array<{ title?: string; url?: string; content?: string }>;
  };
  return (json.results ?? []).map((r) => ({
    name: r.title ?? r.url ?? 'Result',
    url: r.url ?? '',
    snippet: (r.content ?? '').slice(0, 400),
  }));
}

async function searchWikipedia(query: string): Promise<SearchResult[]> {
  const url = new URL('https://en.wikipedia.org/w/api.php');
  url.searchParams.set('action', 'query');
  url.searchParams.set('list', 'search');
  url.searchParams.set('srsearch', query);
  url.searchParams.set('srlimit', '6');
  url.searchParams.set('format', 'json');
  url.searchParams.set('origin', '*');
  const res = await gateway.request('web-search', url.toString(), {
    signal: AbortSignal.timeout(12_000),
  });
  if (!res.ok) throw new Error(`Wikipedia search failed (HTTP ${res.status})`);
  const json = (await res.json()) as {
    query?: { search?: Array<{ title: string; snippet: string; pageid: number }> };
  };
  return (json.query?.search ?? []).map((r) => ({
    name: r.title,
    url: `https://en.wikipedia.org/?curid=${r.pageid}`,
    snippet: stripHtml(r.snippet),
  }));
}

class SearchService {
  /** Searches with Tavily when a key is set, otherwise Wikipedia. */
  async search(query: string): Promise<SearchResponse> {
    const q = query.trim().slice(0, 400);
    if (!q) throw new Error('Search query is empty.');
    const key = searchKeyStore.get();
    if (key) return { provider: 'tavily', results: await searchTavily(q, key) };
    return { provider: 'wikipedia', results: await searchWikipedia(q) };
  }
}

export const searchService = new SearchService();
