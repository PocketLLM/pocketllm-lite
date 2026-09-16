/**
 * POST /api/suggest — follow-up suggestions.
 *
 * Given the last user message and the assistant's reply, proposes three
 * short, natural follow-up questions the user might ask next. Runs on the
 * same Assist runtime as the enhancer; the client falls back to local
 * template suggestions when offline or blocked by Strict Offline.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { user?: string; assistant?: string };
  try {
    body = (await req.json()) as { user?: string; assistant?: string };
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const user = (body.user ?? '').trim();
  const assistant = (body.assistant ?? '').trim();
  if (!user && !assistant) {
    return NextResponse.json({ error: 'user or assistant is required' }, { status: 400 });
  }

  try {
    const zai = await ZAI.create();
    const completion = await zai.chat.completions.create({
      messages: [
        {
          role: 'system',
          content:
            'You propose follow-up questions for a chat between a user and an AI assistant. ' +
            'Read the exchange and suggest exactly THREE distinct, natural follow-up questions the user might ask next. ' +
            'Rules: each question under 9 words; no numbering, no quotes, no explanation; ' +
            'they must relate to the actual topic; vary the angle (go deeper, apply it, challenge it). ' +
            'Output ONLY a JSON array of three strings, e.g. ["How does X work?","Can you show an example?","What are the risks?"]',
        },
        {
          role: 'user',
          content:
            `User asked: ${user.slice(0, 1500) || '(empty)'}\n\nAssistant replied: ${assistant.slice(0, 2500) || '(empty)'}`,
        },
      ],
    });

    const content =
      (completion as { choices?: Array<{ message?: { content?: string } }> })
        .choices?.[0]?.message?.content ?? '';

    // The model may wrap the array in a code fence — extract the first
    // JSON array found in the reply and validate its shape honestly.
    const match = /\[[\s\S]*\]/.exec(content);
    if (!match) {
      return NextResponse.json({ error: 'Model returned no suggestion list' }, { status: 502 });
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(match[0]);
    } catch {
      return NextResponse.json({ error: 'Model returned malformed JSON' }, { status: 502 });
    }
    const suggestions = Array.isArray(parsed)
      ? parsed
          .filter((s): s is string => typeof s === 'string')
          .map((s) => s.trim())
          .filter(Boolean)
          .slice(0, 3)
      : [];
    if (suggestions.length === 0) {
      return NextResponse.json({ error: 'No usable suggestions' }, { status: 502 });
    }
    return NextResponse.json({ suggestions });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Suggest failed';
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
