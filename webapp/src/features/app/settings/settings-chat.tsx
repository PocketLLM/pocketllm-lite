'use client';

/**
 * Chat — default runtime + model pickers fed by the inference router,
 * plus message-behaviour switches.
 */
import { useEffect, useState } from 'react';
import { TriangleAlert } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import { Section } from '@/features/app/shared/ui';
import { Footnote, SettingRow, SettingRows, SettingsSelect } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import type { RuntimeId } from '@/lib/types/domain';

export function ChatSettings() {
  const chat = useAppStore((s) => s.settings.chat);
  const strictOffline = useAppStore((s) => s.settings.privacy.strictOffline);
  const models = useAppStore((s) => s.models);
  const patchSettings = useAppStore((s) => s.patchSettings);

  const runtimes = inferenceRouter.list();
  const runtimeOptions = runtimes.map((r) => ({
    value: r.id,
    label: r.label,
    hint: r.isLocal ? 'local' : 'network',
  }));

  const runtimeModels = models.filter((m) => m.runtimeId === chat.defaultRuntimeId);
  const modelOptions = runtimeModels.map((m) => ({
    value: m.id,
    label: m.label,
    hint: m.detail,
  }));

  const changeRuntime = (value: string) => {
    const id = value as RuntimeId;
    // Keep the default model consistent with the chosen runtime.
    const first = models.find((m) => m.runtimeId === id);
    patchSettings({ chat: { defaultRuntimeId: id, defaultModelId: first?.id ?? '' } });
  };

  const [maxContext, setMaxContext] = useState(String(chat.maxContextMessages));
  useEffect(() => setMaxContext(String(chat.maxContextMessages)), [
    chat.maxContextMessages,
  ]);
  const commitMaxContext = () => {
    const parsed = Math.round(Number(maxContext));
    const clamped = Number.isFinite(parsed) ? Math.min(100, Math.max(10, parsed)) : 30;
    if (clamped !== chat.maxContextMessages) {
      patchSettings({ chat: { maxContextMessages: clamped } });
    }
    setMaxContext(String(clamped));
  };

  const blockedByStrictOffline =
    strictOffline && (chat.defaultRuntimeId === 'assist' || chat.defaultRuntimeId === 'openai');

  return (
    <Section
      title="Chat"
      description="Defaults for new chats. You can override the runtime and model per chat."
    >
      {blockedByStrictOffline && (
        <div className="mb-4 flex gap-2.5 rounded-xl border border-warning/40 bg-warning/10 p-3" role="status">
          <TriangleAlert className="mt-0.5 h-4 w-4 shrink-0 text-warning" aria-hidden />
          <p className="text-[13px] leading-relaxed">
            Strict Offline is on, so this runtime cannot respond. Only the
            Offline Sandbox (and loopback Ollama, if allowed) can generate
            while it stays on. Change it in{' '}
            <button
              type="button"
              className="font-medium underline underline-offset-2"
              onClick={() => router.navigate('/app/settings/privacy')}
            >
              Settings → Privacy
            </button>
            .
          </p>
        </div>
      )}

      <SettingRows>
        <SettingRow
          label="Default runtime"
          description="Where new chats send their messages. Local runtimes stay on your machine."
          htmlFor="setting-runtime"
          control={
            <SettingsSelect
              id="setting-runtime"
              ariaLabel="Default runtime"
              value={chat.defaultRuntimeId}
              onValueChange={changeRuntime}
              options={runtimeOptions}
            />
          }
        />
        <SettingRow
          label="Default model"
          description={
            runtimeModels.length
              ? 'Models the selected runtime currently lists.'
              : 'No models listed for this runtime yet — it will fall back to its own default.'
          }
          htmlFor="setting-model"
          control={
            <SettingsSelect
              id="setting-model"
              ariaLabel="Default model"
              value={chat.defaultModelId}
              onValueChange={(v) => patchSettings({ chat: { defaultModelId: v } })}
              options={modelOptions}
              placeholder="Runtime default"
            />
          }
        />
        <SettingRow
          label="Streaming responses"
          description="Show words as they arrive instead of waiting for the full reply."
          control={
            <Switch
              checked={chat.streamingEnabled}
              onCheckedChange={(v) => patchSettings({ chat: { streamingEnabled: v } })}
              aria-label="Streaming responses"
            />
          }
        />
        <SettingRow
          label="Auto-title new chats"
          description="Ask for a short title after the first reply. Titles use the Assist runtime, so they pause while Strict Offline is on."
          control={
            <Switch
              checked={chat.autoTitle}
              onCheckedChange={(v) => patchSettings({ chat: { autoTitle: v } })}
              aria-label="Auto-title new chats"
            />
          }
        />
        <SettingRow
          label="Token counters"
          description="Estimated tokens in/out under each response."
          control={
            <Switch
              checked={chat.showTokenCounters}
              onCheckedChange={(v) => patchSettings({ chat: { showTokenCounters: v } })}
              aria-label="Token counters"
            />
          }
        />
        <SettingRow
          label="Always show timestamps"
          description="Keep a small clock under every message instead of revealing it on hover."
          control={
            <Switch
              checked={chat.showTimestamps === 'always'}
              onCheckedChange={(v) =>
                patchSettings({ chat: { showTimestamps: v ? 'always' : 'hover' } })
              }
              aria-label="Always show timestamps"
            />
          }
        />
        <SettingRow
          label="Follow-up suggestions"
          description="Offer three follow-up questions after each reply. Generated through the Assist runtime; template questions are used while offline."
          control={
            <Switch
              checked={chat.followUpSuggestions}
              onCheckedChange={(v) => patchSettings({ chat: { followUpSuggestions: v } })}
              aria-label="Follow-up suggestions"
            />
          }
        />
        <SettingRow
          label="Context window"
          description="How many recent messages (10–100) are sent as conversation context."
          htmlFor="setting-max-context"
          control={
            <Input
              id="setting-max-context"
              type="number"
              min={10}
              max={100}
              value={maxContext}
              onChange={(e) => setMaxContext(e.target.value)}
              onBlur={commitMaxContext}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  commitMaxContext();
                  e.currentTarget.blur();
                }
              }}
              className="w-24"
            />
          }
        />
      </SettingRows>

      <Footnote>
        Token counts are estimates (~4 characters per token) — this build has no
        local tokenizer for every model.
      </Footnote>
    </Section>
  );
}
