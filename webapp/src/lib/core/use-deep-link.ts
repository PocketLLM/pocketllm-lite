'use client';

/**
 * useDeepLink — React bridge for the DeepLink hand-off.
 *
 * Manager views use this to react to live (same-route) palette selections.
 * Cross-route requests are consumed on mount by the views themselves (via
 * `deepLink.take()` inside their load functions); this hook covers the case
 * where the target view is already on screen and will not remount.
 */
import { useEffect, useRef } from 'react';
import { DEEP_LINK_EVENT, type DeepLinkKind } from './deep-link';

export function useDeepLink<T>(
  kind: DeepLinkKind,
  resolve: (id: string) => T | undefined,
  apply: (item: T) => void
): void {
  // Keep the latest resolvers without resubscribing the listener.
  const resolveRef = useRef(resolve);
  const applyRef = useRef(apply);

  useEffect(() => {
    resolveRef.current = resolve;
    applyRef.current = apply;
  }, [resolve, apply]);

  useEffect(() => {
    const handler = (e: Event) => {
      const detail = (e as CustomEvent<{ kind: DeepLinkKind; id: string }>).detail;
      if (!detail || detail.kind !== kind) return;
      const item = resolveRef.current(detail.id);
      if (item) applyRef.current(item);
    };
    window.addEventListener(DEEP_LINK_EVENT, handler);
    return () => window.removeEventListener(DEEP_LINK_EVENT, handler);
  }, [kind]);
}
