/**
 * POST /api/vision — multimodal (text+image) chat completions.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

interface VisionBody {
  messages?: Array<{
    role: string;
    content:
      | string
      | Array<
          | { type: 'text'; text: string }
          | { type: 'image_url'; image_url: { url: string } }
        >;
  }>;
  stream?: boolean;
}

export async function POST(req: NextRequest) {
  let body: VisionBody;
  try {
    body = (await req.json()) as VisionBody;
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return NextResponse.json({ error: 'messages[] is required' }, { status: 400 });
  }

  try {
    const zai = await ZAI.create();
    const stream = await zai.chat.completions.createVision({
      model: 'glm-4.5v',
      messages: body.messages.map((m) => ({
        role: m.role === 'user' || m.role === 'system' ? m.role : 'assistant',
        content: m.content,
      })),
      stream: body.stream !== false,
    });

    if (stream instanceof ReadableStream) {
      return new NextResponse(stream as unknown as ReadableStream, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache, no-transform',
        },
      });
    }
    return NextResponse.json(stream);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Vision completion failed';
    console.error('[api/vision]', message);
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
