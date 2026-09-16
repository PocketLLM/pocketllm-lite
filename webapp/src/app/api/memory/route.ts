/**
 * POST /api/memory — extracts candidate long-term memories from a
 * finished user/assistant exchange. Returns STRICT JSON; the client
 * validates every field before storing anything.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

interface MemoryCandidate {
  fact: string;
  subject: string;
  type: 'fact' | 'preference' | 'instruction' | 'context';
  confidence: number;
}

export async function POST(req: NextRequest) {
  let body: { user?: string; assistant?: string };
  try {
    body = (await req.json()) as { user?: string; assistant?: string };
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }
  const user = (body.user ?? '').trim();
  if (!user) {
    return NextResponse.json({ error: 'user message is required' }, { status: 400 });
  }

  try {
    const zai = await ZAI.create();
    const completion = await zai.chat.completions.create({
      messages: [
        {
          role: 'system',
          content: `You extract long-term memories about the USER from a conversation exchange. Rules:
- Only durable facts worth remembering across future chats (name, preferences, projects, constraints, goals).
- NEVER store secrets: API keys, passwords, tokens, card numbers, addresses — skip them entirely.
- Each memory: fact (one sentence), subject (topic key like "name", "coffee preference"), type (fact|preference|instruction|context), confidence (0.0-1.0).
- Max 3 memories. Skip trivial small talk.
Respond with ONLY a JSON array: [{"fact": "...", "subject": "...", "type": "...", "confidence": 0.9}]. Empty array [] if nothing is worth remembering.`,
        },
        {
          role: 'user',
          content: `USER SAID:\n${user.slice(0, 4000)}\n\nASSISTANT REPLIED:\n${(body.assistant ?? '').slice(0, 4000)}`,
        },
      ],
    });
    const content =
      (completion as { choices?: Array<{ message?: { content?: string } }> })
        .choices?.[0]?.message?.content ?? '';

    // Parse defensively — strip code fences if present.
    const cleaned = content.replace(/```json\s*|```/g, '').trim();
    let memories: MemoryCandidate[] = [];
    try {
      const parsed = JSON.parse(cleaned) as unknown;
      if (Array.isArray(parsed)) {
        memories = parsed
          .filter(
            (m): m is MemoryCandidate =>
              !!m &&
              typeof m.fact === 'string' &&
              m.fact.length > 3 &&
              typeof m.confidence === 'number'
          )
          .slice(0, 5)
          .map((m) => ({
            fact: String(m.fact).slice(0, 400),
            subject: String(m.subject ?? 'general').slice(0, 100),
            type: (['fact', 'preference', 'instruction', 'context'] as const).includes(
              m.type
            )
              ? m.type
              : 'fact',
            confidence: Math.min(1, Math.max(0, Number(m.confidence) || 0.5)),
          }));
      }
    } catch {
      memories = [];
    }
    return NextResponse.json({ memories });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Memory extraction failed';
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
