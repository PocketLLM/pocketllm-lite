/**
 * POST /api/asr — audio transcription (speech-to-text).
 * Receives base64 audio; returns the transcribed text.
 */
import { NextRequest, NextResponse } from 'next/server';
import ZAI from 'z-ai-web-dev-sdk';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { audio_base64?: string; mime_type?: string };
  try {
    body = (await req.json()) as { audio_base64?: string; mime_type?: string };
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }
  const audio = (body.audio_base64 ?? '').trim();
  if (!audio) {
    return NextResponse.json({ error: 'audio_base64 is required' }, { status: 400 });
  }
  // Guard payload size (~25 MB of audio).
  if (audio.length > 34_000_000) {
    return NextResponse.json(
      { error: 'Audio is too large (over ~25 MB). Record a shorter clip.' },
      { status: 413 }
    );
  }

  try {
    const zai = await ZAI.create();
    const result = await zai.audio.asr.create({
      file_base64: audio,
    });
    const text =
      (result as { text?: string }).text ??
      (result as { result?: string }).result ??
      '';
    return NextResponse.json({ text });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Transcription failed';
    console.error('[api/asr]', message);
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
