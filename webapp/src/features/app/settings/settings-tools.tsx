'use client';

/**
 * Tools — which built-in tools the assistant may call, and whether
 * risky ones ask first. All evaluation stays local.
 */
import { ShieldCheck } from 'lucide-react';
import { Switch } from '@/components/ui/switch';
import { Section } from '@/features/app/shared/ui';
import { Footnote, SettingRow, SettingRows } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';

interface ToolDef {
  key: 'calculator' | 'notes' | 'clipboard' | 'webSearch' | 'draftEmail' | 'openUrl' | 'deviceInfo' | 'webhook';
  label: string;
  description: string;
}

const TOOLS: ToolDef[] = [
  { key: 'calculator', label: 'Calculator', description: 'Safe arithmetic evaluator.' },
  { key: 'notes', label: 'Notes', description: 'Create notes via chat.' },
  { key: 'clipboard', label: 'Clipboard', description: 'Copy text via chat.' },
  {
    key: 'webSearch',
    label: 'Web search',
    description: "Search the web via the app's search endpoint.",
  },
  { key: 'draftEmail', label: 'Draft email', description: 'Open mailto: drafts.' },
  { key: 'openUrl', label: 'Open URL', description: 'Open links after approval.' },
  {
    key: 'deviceInfo',
    label: 'Device info',
    description: 'Share measured browser info.',
  },
  {
    key: 'webhook',
    label: 'Webhook',
    description: 'Outbound HTTP after approval — advanced.',
  },
];

export function ToolsSettings() {
  const tools = useAppStore((s) => s.settings.tools);
  const patchSettings = useAppStore((s) => s.patchSettings);

  return (
    <Section
      title="Tools"
      description="Built-in capabilities the assistant may call mid-conversation. The model decides when; these switches decide whether it can."
    >
      <SettingRows>
        <SettingRow
          label="Require confirmation"
          description="Master switch — when on, consequential tools (like web search or opening links) ask for your approval in chat before running."
          control={
            <Switch
              checked={tools.requireConfirmation}
              onCheckedChange={(v) => patchSettings({ tools: { requireConfirmation: v } })}
              aria-label="Require tool confirmation"
            />
          }
        />
        {TOOLS.map((tool) => (
          <SettingRow
            key={tool.key}
            label={tool.label}
            description={tool.description}
            control={
              <Switch
                checked={tools[tool.key]}
                onCheckedChange={(v) => patchSettings({ tools: { [tool.key]: v } })}
                aria-label={`${tool.label} tool`}
              />
            }
          />
        ))}
      </SettingRows>

      <Footnote>
        <span className="inline-flex items-center gap-1.5">
          <ShieldCheck className="h-3.5 w-3.5" aria-hidden />
          Tool calls and their arguments are validated locally before anything
          runs — the model can never invent a tool or widen its own permissions.
        </span>
      </Footnote>
    </Section>
  );
}
