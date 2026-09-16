/**
 * POST /api/title — generates a short chat title from the first
 * user message.
 *
 * Resilience: upstream 429 (rate limit) responses and transient network
 * faults are retried with exponential backoff before giving up, so rapid
 * chat-creation bursts no longer strand chats with the generic
 * "New chat" title.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/** Millisecond delays applied before each retry attempt. */
const RETRY_DELAYS_MS = [900, 2200] as const;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const TITLE_SYSTEM_PROMPT =
  'Generate a 2-5 word title for a chat that starts with the message below. Use the same language as the message. Title Case. Output ONLY the title — no quotes, no punctuation at the end.';

/** True when the thrown error is an upstream rate-limit rejection. */
function isRateLimit(err: unknown): boolean {
  return err instanceof Error && /\b429\b/.test(err.message);
}

/** True when the upstream request failed for transient network reasons. */
function isTransientNetwork(err: unknown): boolean {
  return (
    err instanceof Error &&
    /(?:fetch failed|network|ECONNRESET|ETIMEDOUT|aborted|terminated)/i.test(
      err.message,
    )
  );
}

/** One title-completion attempt; throws through to the caller on failure. */
async function attemptTitle(message: string): Promise<string> {
  const zai = await ZAI.create();
  const completion = await zai.chat.completions.create({
    messages: [
      { role: 'system', content: TITLE_SYSTEM_PROMPT },
      { role: 'user', content: message.slice(0, 600) },
    ],
  });
  return (
    (completion as { choices?: Array<{ message?: { content?: string } }> })
      .choices?.[0]?.message?.content
      ?.trim()
      ?.replace(/^["'«»]|["'«».]$/g, '')
      ?.slice(0, 80) ?? ''
  );
}

export async function POST(req: NextRequest) {
  let body: { message?: string };
  try {
    body = (await req.json()) as { message?: string };
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }
  const message = (body.message ?? '').trim();
  if (!message) {
    return NextResponse.json({ error: 'message is required' }, { status: 400 });
  }

  let title = '';
  let lastErr: unknown = null;
  for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt += 1) {
    if (attempt > 0) {
      // Only rate limits and transient network faults are worth retrying;
      // anything else (bad request, auth, …) fails fast.
      if (!isRateLimit(lastErr) && !isTransientNetwork(lastErr)) break;
      await sleep(RETRY_DELAYS_MS[attempt - 1]);
    }
    try {
      title = await attemptTitle(message);
      lastErr = null;
      break;
    } catch (err) {
      lastErr = err;
    }
  }

  if (lastErr !== null) {
    const message2 = lastErr instanceof Error ? lastErr.message : 'Title failed';
    return NextResponse.json({ error: message2 }, { status: 502 });
  }
  return NextResponse.json({ title: title || 'New chat' });
}
