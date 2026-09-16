'use client';

/**
 * Privacy — the network policy switches. Strict Offline is the big
 * one: it blocks the built-in Assist runtime and the internet.
 */
import { ShieldCheck, TriangleAlert } from 'lucide-react';
import { Switch } from '@/components/ui/switch';
import { Section } from '@/features/app/shared/ui';
import { Footnote, SettingRow, SettingRows } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';

export function PrivacySettings() {
  const privacy = useAppStore((s) => s.settings.privacy);
  const patchSettings = useAppStore((s) => s.patchSettings);

  return (
    <div className="space-y-6">
      <Section
        title="Privacy"
        description="PocketLLM has no account and no server-side profile. These switches control what leaves this browser — nothing else does."
      >
        <SettingRows>
          <SettingRow
            label="Strict Offline"
            description="Block all internet access. The built-in Assist runtime stops working; the Offline Sandbox and loopback Ollama keep responding."
            control={
              <Switch
                checked={privacy.strictOffline}
                onCheckedChange={(v) => patchSettings({ privacy: { strictOffline: v } })}
                aria-label="Strict Offline"
              />
            }
          />
          <SettingRow
            label="Allow loopback (localhost)"
            description="Connections to 127.0.0.1 and ::1 — required for Ollama running on this machine."
            control={
              <Switch
                checked={privacy.allowLoopback}
                onCheckedChange={(v) => patchSettings({ privacy: { allowLoopback: v } })}
                aria-label="Allow loopback connections"
              />
            }
          />
          <SettingRow
            label="Allow LAN connections"
            description="Private-network hosts like 192.168.x.x, 10.x.x.x and *.local — an Ollama server on another computer, for example."
            control={
              <Switch
                checked={privacy.allowLan}
                onCheckedChange={(v) => patchSettings({ privacy: { allowLan: v } })}
                aria-label="Allow LAN connections"
              />
            }
          />
          <SettingRow
            label="Audit network requests"
            description="Record every app-owned network request, allowed and blocked, in the Network page — never records prompt bodies."
            control={
              <Switch
                checked={privacy.auditNetwork}
                onCheckedChange={(v) => patchSettings({ privacy: { auditNetwork: v } })}
                aria-label="Audit network requests"
              />
            }
          />
        </SettingRows>
      </Section>

      {privacy.strictOffline && (
        <Section className="border-warning/50">
          <div className="flex gap-3">
            <TriangleAlert
              className="mt-0.5 h-5 w-5 shrink-0 text-warning"
              aria-hidden
            />
            <div>
              <h2 className="text-[15px] font-semibold">Strict Offline is on</h2>
              <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                Blocks the built-in Assist runtime and all internet access.
                Only the Offline Sandbox and loopback Ollama can respond. New
                chats will use whichever of those is available; web search,
                prompt enhancement and auto-titles pause while this is on.
              </p>
              <button
                type="button"
                className="mt-2 inline-flex items-center gap-1.5 text-[13px] font-medium text-foreground underline underline-offset-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                onClick={() => router.navigate('/app/network')}
              >
                <ShieldCheck className="h-3.5 w-3.5" aria-hidden />
                See exactly what was blocked on the Network page
              </button>
            </div>
          </div>
        </Section>
      )}

      <Footnote>
        The policy applies at request time, instantly — no reload needed. Every
        blocked attempt is still audited when auditing is on, so you can verify
        the block on the Network page.
      </Footnote>
    </div>
  );
}
