'use client';

/**
 * Shared app-level UI primitives used across feature pages.
 * Small, dependency-free, a11y-conscious.
 */
import { cn } from '@/lib/utils';

/** Standard page header for manager pages. */
export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3 pb-6">
      <div>
        <h1 className="font-display text-xl font-semibold tracking-tight sm:text-2xl">
          {title}
        </h1>
        {description && (
          <p className="mt-1 max-w-xl text-sm text-muted-foreground">{description}</p>
        )}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}

/** Empty state with icon + optional action. */
export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border px-6 py-16 text-center">
      <div className="rounded-2xl bg-muted p-3">
        <Icon className="h-6 w-6 text-muted-foreground" />
      </div>
      <h3 className="mt-4 text-[15px] font-medium">{title}</h3>
      {description && (
        <p className="mt-1 max-w-sm text-sm text-muted-foreground">{description}</p>
      )}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

/** Status dot with label (success / warning / error / neutral). */
export function StatusDot({
  tone = 'neutral',
  children,
}: {
  tone?: 'success' | 'warning' | 'error' | 'neutral' | 'accent';
  children?: React.ReactNode;
}) {
  const tones: Record<string, string> = {
    success: 'bg-success',
    warning: 'bg-warning',
    error: 'bg-destructive',
    accent: 'bg-brand-strong',
    neutral: 'bg-muted-foreground/40',
  };
  return (
    <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
      <span className={cn('h-1.5 w-1.5 rounded-full', tones[tone])} />
      {children}
    </span>
  );
}

/** Compact pill for metadata. */
export function MetaPill({
  children,
  tone = 'default',
}: {
  children: React.ReactNode;
  tone?: 'default' | 'accent' | 'outline';
}) {
  const tones = {
    default: 'bg-muted text-muted-foreground',
    accent: 'bg-brand text-brand-foreground font-medium',
    outline: 'border border-border text-muted-foreground',
  };
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px]',
        tones[tone]
      )}
    >
      {children}
    </span>
  );
}

/** Toolbar wrapper for list pages (search + filters row). */
export function ListToolbar({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-center gap-2 pb-4">{children}</div>
  );
}

/** Section card used by settings + managers. */
export function Section({
  title,
  description,
  actions,
  children,
  className,
}: {
  title?: string;
  description?: string;
  /** Optional toolbar rendered right-aligned in the section header. */
  actions?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn(
        'rounded-2xl border border-border bg-card p-5 sm:p-6',
        className
      )}
    >
      {(title || description || actions) && (
        <header className="mb-4 flex flex-wrap items-start justify-between gap-2">
          <div>
            {title && <h2 className="text-[15px] font-semibold">{title}</h2>}
            {description && (
              <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                {description}
              </p>
            )}
          </div>
          {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
        </header>
      )}
      {children}
    </section>
  );
}
