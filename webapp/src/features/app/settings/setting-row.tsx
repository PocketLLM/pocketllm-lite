'use client';

/**
 * Shared settings primitives — dense, labeled rows used by every
 * settings section. Controls are plain shadcn pieces wired straight
 * to the live settings object, so every change saves immediately.
 */
import { useEffect, useState } from 'react';
import { Check } from 'lucide-react';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { cn } from '@/lib/utils';
import { bus } from '@/lib/core/events/event-bus';

/* --------------------------- setting rows ---------------------------- */

/**
 * One setting: label + description on the left, control on the right.
 * `wide` puts the control on its own full-width line (sliders, previews).
 */
export function SettingRow({
  label,
  description,
  control,
  htmlFor,
  wide = false,
  disabled = false,
  danger = false,
  valueLabel,
}: {
  label: string;
  description?: React.ReactNode;
  control: React.ReactNode;
  htmlFor?: string;
  wide?: boolean;
  disabled?: boolean;
  danger?: boolean;
  valueLabel?: string;
}) {
  const labelEl = (
    <Label
      htmlFor={htmlFor}
      className={cn(
        'text-sm font-medium leading-snug',
        danger && 'text-destructive',
        disabled && 'opacity-60'
      )}
    >
      {label}
    </Label>
  );
  const descEl = description && (
    <p
      className={cn(
        'mt-0.5 max-w-lg text-xs leading-relaxed text-muted-foreground',
        disabled && 'opacity-60'
      )}
    >
      {description}
    </p>
  );

  if (wide) {
    return (
      <div className={cn('py-3.5', disabled && 'opacity-60')}>
        <div className="flex items-baseline justify-between gap-4">
          <div className="min-w-0">
            {labelEl}
            {descEl}
          </div>
          {valueLabel && (
            <span className="shrink-0 font-mono text-xs text-muted-foreground">
              {valueLabel}
            </span>
          )}
        </div>
        <div className={cn('mt-2.5', disabled && 'pointer-events-none')}>
          {control}
        </div>
      </div>
    );
  }

  return (
    <div
      className={cn(
        'flex flex-col gap-2.5 py-3.5 sm:flex-row sm:items-center sm:justify-between sm:gap-6',
        disabled && 'opacity-60'
      )}
    >
      <div className="min-w-0">
        {labelEl}
        {descEl}
      </div>
      <div className={cn('shrink-0', disabled && 'pointer-events-none')}>
        {control}
      </div>
    </div>
  );
}

/** Vertical stack of SettingRows with hairline separators. */
export function SettingRows({ children }: { children: React.ReactNode }) {
  return <div className="divide-y divide-border">{children}</div>;
}

/* ------------------------------ selects ------------------------------ */

export interface SelectOption {
  value: string;
  label: string;
  /** Secondary text shown after the label, e.g. "local". */
  hint?: string;
  disabled?: boolean;
}

/** Labeled shadcn Select sized for settings rows. */
export function SettingsSelect({
  id,
  value,
  onValueChange,
  options,
  ariaLabel,
  placeholder,
  className,
}: {
  id?: string;
  value: string;
  onValueChange: (value: string) => void;
  options: SelectOption[];
  ariaLabel: string;
  placeholder?: string;
  className?: string;
}) {
  return (
    <Select value={value} onValueChange={onValueChange}>
      <SelectTrigger
        id={id}
        aria-label={ariaLabel}
        className={cn('w-full sm:w-[220px]', className)}
      >
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent>
        {options.map((o) => (
          <SelectItem key={o.value} value={o.value} disabled={o.disabled}>
            <span className="truncate">{o.label}</span>
            {o.hint && (
              <span className="text-xs text-muted-foreground">· {o.hint}</span>
            )}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}

/* --------------------------- saved feedback --------------------------- */

/**
 * Subtle "Saved" indicator. Flashes for ~1.4s after every
 * `settings:changed` event — which patchSettings emits on each save.
 */
export function SavedFlash() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null;
    const unsub = bus.on('settings:changed', () => {
      setShow(true);
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => setShow(false), 1400);
    });
    return () => {
      unsub();
      if (timer) clearTimeout(timer);
    };
  }, []);

  return (
    <span
      aria-live="polite"
      className={cn(
        'inline-flex items-center gap-1 text-xs font-medium text-success transition-opacity duration-300',
        show ? 'opacity-100' : 'opacity-0'
      )}
    >
      <Check className="h-3.5 w-3.5" aria-hidden />
      Saved
    </span>
  );
}

/* ---------------------------- misc helpers --------------------------- */

/** Small muted footnote used under sections. */
export function Footnote({ children }: { children: React.ReactNode }) {
  return (
    <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
      {children}
    </p>
  );
}
