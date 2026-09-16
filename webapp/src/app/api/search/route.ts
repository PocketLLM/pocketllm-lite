/**
 * POST /api/search — web search for the web_search tool.
 * Uses the z-ai SDK's function invocation layer.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { query?: string };
  try {
    body = (await req.json()) as { query?: string };
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }
  const query = (body.query ?? '').trim();
  if (!query) {
    return NextResponse.json({ error: 'query is required' }, { status: 400 });
  }

  try {
    const zai = await ZAI.create();
    const results = await zai.functions.invoke('web_search', {
      query: query.slice(0, 400),
      num: 6,
    });
    return NextResponse.json({
      results: (results ?? []).map((r) => ({
        name: r.name,
        url: r.url,
        snippet: r.snippet,
      })),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Search failed';
    console.error('[api/search]', message);
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
