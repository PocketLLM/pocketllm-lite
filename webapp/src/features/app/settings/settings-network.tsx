'use client';

/**
 * Network — read-only map of the purposes this app may issue network
 * requests for, plus a pointer to the Network audit page.
 */
import { ArrowRight, Globe } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Section } from '@/features/app/shared/ui';
import { Footnote } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';

/** Plain-language explanation per network purpose. */
const PURPOSE_INFO: Record<string, string> = {
  'assist-inference': 'Chat completions for the built-in Assist runtime.',
  'assist-vision': 'Image understanding for the Assist runtime.',
  'assist-enhance': 'Prompt enhancement via the Assist runtime.',
  'assist-title': 'Automatic chat titles via the Assist runtime.',
  'assist-memory': 'Memory extraction via the Assist runtime.',
  'assist-search': 'Web search results delivered through the Assist runtime.',
  'assist-asr': 'Speech-to-text via the Assist runtime.',
  'ollama-loopback': 'Requests to your local Ollama server on localhost.',
  'ollama-lan': 'Requests to an Ollama server on your local network.',
  'remote-inference': 'Chat completions on an OpenAI-compatible endpoint you configured.',
  'huggingface-search': 'Searching the Hugging Face model catalog.',
  'huggingface-download': 'Downloading model files from Hugging Face.',
  'github-skill': 'Fetching a skill definition from GitHub when you add one.',
  'update-check': 'Checking for PocketLLM app updates.',
  'external-resource': 'Other app-owned resources you explicitly approve.',
  webhook: 'Outbound webhook calls from the webhook tool.',
};

export function NetworkSettings() {
  const purposes = useAppStore((s) => s.settings.network.allowedPurposes);

  return (
    <div className="space-y-6">
      <Section
        title="Network"
        description="Everything this app may contact, and why. The list is managed by the app — you steer it with the Privacy switches."
      >
        <ul className="space-y-3">
          {purposes.map((purpose) => (
            <li key={purpose} className="flex flex-col gap-1">
              <span className="inline-flex w-fit items-center rounded-full border border-border bg-muted px-2.5 py-0.5 font-mono text-[11px] text-muted-foreground">
                {purpose}
              </span>
              <p className="text-xs leading-relaxed text-muted-foreground">
                {PURPOSE_INFO[purpose] ?? 'App-owned network purpose.'}
              </p>
            </li>
          ))}
        </ul>
        <Footnote>
          Strict Offline, loopback and LAN switches (Privacy) decide at request
          time whether a purpose may actually connect — and every attempt,
          allowed or blocked, lands in the audit log when auditing is on.
        </Footnote>
      </Section>

      <Section>
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex min-w-0 gap-3">
            <Globe className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground" aria-hidden />
            <div>
              <h2 className="text-[15px] font-semibold">Network audit page</h2>
              <p className="mt-1 max-w-lg text-[13px] leading-relaxed text-muted-foreground">
                A chronological record of every app-owned request — purpose,
                destination, allowed or blocked, and the reason. Never includes
                prompt bodies.
              </p>
            </div>
          </div>
          <Button variant="outline" onClick={() => router.navigate('/app/network')}>
            Open Network
            <ArrowRight aria-hidden />
          </Button>
        </div>
      </Section>
    </div>
  );
}
