/**
 * POST /api/enhance — prompt enhancer.
 * Rewrites a rough prompt into a clear, specific instruction.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { prompt?: string };
  try {
    body = (await req.json()) as { prompt?: string };
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }
  const prompt = (body.prompt ?? '').trim();
  if (!prompt) {
    return NextResponse.json({ error: 'prompt is required' }, { status: 400 });
  }

  try {
    const zai = await ZAI.create();
    const completion = await zai.chat.completions.create({
      messages: [
        {
          role: 'system',
          content:
            'You are a prompt-enhancement assistant. Rewrite the user\'s rough prompt into a single, clear, self-contained instruction for an AI assistant. Preserve the user\'s intent and language. Keep it under 120 words. Output ONLY the improved prompt — no preamble, no quotes, no explanation.',
        },
        { role: 'user', content: prompt.slice(0, 4000) },
      ],
    });
    const content =
      (completion as { choices?: Array<{ message?: { content?: string } }> })
        .choices?.[0]?.message?.content ?? '';
    return NextResponse.json({ prompt: content.trim() });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Enhance failed';
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
