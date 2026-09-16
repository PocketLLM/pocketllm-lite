/**
 * GET /api/hf?q=<query> — Hugging Face GGUF repository search proxy.
 * Runs server-side to avoid CORS entirely; only public metadata is
 * fetched (no tokens involved).
 */
import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

interface HFRepo {
  id: string;
  likes?: number;
  downloads?: number;
  tags?: string[];
  lastModified?: string;
  pipeline_tag?: string;
}

export async function GET(req: NextRequest) {
  const q = (req.nextUrl.searchParams.get('q') ?? '').trim();
  if (!q) {
    return NextResponse.json({ repositories: [] });
  }

  try {
    const url = new URL('https://huggingface.co/api/models');
    url.searchParams.set('search', `${q} GGUF`);
    url.searchParams.set('limit', '20');
    url.searchParams.set('full', 'false');
    url.searchParams.set('sort', 'downloads');
    url.searchParams.set('direction', '-1');

    const res = await fetch(url.toString(), {
      headers: { 'User-Agent': 'PocketLLM-Lite-Web' },
      signal: AbortSignal.timeout(12_000),
    });
    if (!res.ok) {
      return NextResponse.json(
        { error: `Hugging Face returned ${res.status}` },
        { status: 502 }
      );
    }
    const repos = (await res.json()) as HFRepo[];
    const repositories = repos
      .filter((r) => (r.tags ?? []).some((t) => t === 'gguf'))
      .map((r) => ({
        id: r.id,
        author: r.id.split('/')[0] ?? 'unknown',
        likes: r.likes ?? 0,
        downloads: r.downloads ?? 0,
        license: (r.tags ?? []).find((t) => t.startsWith('license:'))?.replace('license:', '') ?? 'unknown',
        lastModified: r.lastModified,
        repoUrl: `https://huggingface.co/${r.id}`,
      }));
    return NextResponse.json({ repositories });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Search failed';
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
