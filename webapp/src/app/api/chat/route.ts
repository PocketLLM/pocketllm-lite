/**
 * POST /api/chat — streaming chat completions.
 *
 * The ONLY place z-ai-web-dev-sdk is used for chat. The client sends
 * OpenAI-style messages; we stream the SSE response through as-is so
 * the client-side AssistRuntime can parse `data:` frames.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

interface ChatBody {
  messages?: Array<{ role: string; content: string }>;
  stream?: boolean;
  temperature?: number;
  top_p?: number;
  max_tokens?: number;
}

/** Roles accepted by the upstream chat API. */
type ApiRole = 'user' | 'system' | 'assistant';

export async function POST(req: NextRequest) {
  let body: ChatBody;
  try {
    body = (await req.json()) as ChatBody;
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return NextResponse.json({ error: 'messages[] is required' }, { status: 400 });
  }
  // Sanitize roles to what the API accepts.
  const sanitized: Array<{ role: ApiRole; content: string }> = messages.map((m) => ({
    role: (m.role === 'user' || m.role === 'system' ? m.role : 'assistant') as ApiRole,
    content: String(m.content ?? '').slice(0, 60_000),
  }));

  try {
    const zai = await ZAI.create();
    const stream = await zai.chat.completions.create({
      messages: sanitized,
      stream: true,
      ...(body.temperature != null ? { temperature: body.temperature } : {}),
      ...(body.top_p != null ? { top_p: body.top_p } : {}),
      ...(body.max_tokens != null ? { max_tokens: body.max_tokens } : {}),
    });

    // The SDK returns a Web ReadableStream for streaming requests.
    if (stream instanceof ReadableStream) {
      return new NextResponse(stream as unknown as ReadableStream, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache, no-transform',
          Connection: 'keep-alive',
        },
      });
    }

    // Non-streaming JSON response fallback.
    return NextResponse.json(stream);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Chat completion failed';
    console.error('[api/chat]', message);
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
