'use client';

/**
 * Tools — which built-in tools the assistant may call, and whether
 * risky ones ask first. All evaluation stays local.
 */
import { useState } from 'react';
import { ShieldCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { searchKeyStore } from '@/lib/services/search-service';
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
    description: "Search the web from your browser — Wikipedia by default, Tavily with your own key.",
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

/** Optional Tavily key for broader web search — kept out of backups and logs. */
function SearchKeyRow() {
  const [value, setValue] = useState('');
  const [remember, setRemember] = useState(false);
  const [where, setWhere] = useState(searchKeyStore.where());

  const save = () => {
    searchKeyStore.set(value, remember);
    setValue('');
    setWhere(searchKeyStore.where());
  };
  const clear = () => {
    searchKeyStore.clear();
    setWhere('none');
  };

  return (
    <SettingRow
      label="Tavily API key"
      wide
      htmlFor="tavily-key"
      description={
        where === 'none'
          ? 'Optional. Without a key, web search uses Wikipedia. Your key is held for this browser session only unless you choose to remember it.'
          : where === 'session'
            ? 'A key is set for this browser session and will be forgotten when you close the tab.'
            : 'A key is remembered on this device (stored unencrypted in this browser).'
      }
      control={
        <div className="flex flex-col gap-2.5 sm:flex-row sm:items-center">
          <Input
            id="tavily-key"
            type="password"
            autoComplete="off"
            placeholder={where === 'none' ? 'tvly-…' : '••••••••••••'}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            className="sm:max-w-xs"
          />
          <label className="flex items-center gap-2 text-xs text-muted-foreground">
            <Switch checked={remember} onCheckedChange={setRemember} aria-label="Remember key on this device" />
            Remember on this device
          </label>
          <div className="flex gap-2">
            <Button size="sm" onClick={save} disabled={!value.trim()}>
              Save
            </Button>
            {where !== 'none' && (
              <Button size="sm" variant="outline" onClick={clear}>
                Remove
              </Button>
            )}
          </div>
        </div>
      }
    />
  );
}

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
        <SearchKeyRow />
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
