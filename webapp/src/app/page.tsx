'use client';

/**
 * Root page — the single user-visible route.
 *
 * Renders either the marketing site (default, `#/…` anchors and
 * marketing sub-pages) or the local-first web application
 * (`#/app/…`) based on the hash. The marketing view server-renders
 * first for instant paint; the app view takes over client-side once
 * the hash is evaluated.
 *
 * Page titles: AppShell owns document.title while the app is mounted
 * (per-route titles); MarketingSite sets it per marketing page. No
 * restore logic is needed here — whichever shell mounts last wins.
 */
import { useEffect, useState } from 'react';
import { MarketingSite } from '@/features/marketing/marketing-site';
import { AppShell } from '@/features/app/shell/app-shell';

export default function Page() {
  const [view, setView] = useState<'marketing' | 'app' | 'pending'>('pending');

  useEffect(() => {
    const apply = () => {
      const hash = window.location.hash;
      const isApp = hash.startsWith('#/app');
      setView(isApp ? 'app' : 'marketing');
    };
    apply();
    window.addEventListener('hashchange', apply);
    return () => window.removeEventListener('hashchange', apply);
  }, []);

  if (view === 'pending') {
    // Avoid a flash of the wrong view during hydration: render the
    // marketing shell skeleton (very cheap, matches SSR paint).
    return <MarketingSite />;
  }

  return view === 'app' ? <AppShell /> : <MarketingSite />;
}
