/**
 * React stores (zustand) — thin bridges between the OOP service layer
 * and React. All heavy logic lives in services; stores subscribe to
 * the event bus and mirror state for rendering.
 */
'use client';

import { create } from 'zustand';
import { useEffect, useState } from 'react';
import { router, type Route } from '@/lib/core/router';
import { bus } from '@/lib/core/events/event-bus';
import { chatService } from '@/lib/services/chat-service';
import { settingsService } from '@/lib/services/settings-service';
import { pipeline, type PipelineStatus } from '@/lib/services/generation-pipeline';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { logService } from '@/lib/services/log-service';
import type { AppSettings, Chat, RuntimeId } from '@/lib/types/domain';

/* ---------------------------- router ------------------------------ */

export function useRoute(): Route {
  const [route, setRoute] = useState<Route>(router.route);
  useEffect(() => {
    const unsub = router.subscribe(setRoute);
    const stop = router.start();
    return () => {
      unsub();
      stop();
    };
  }, []);
  return route;
}

/* --------------------------- app store ----------------------------- */

interface AppState {
  hydrated: boolean;
  chats: Chat[];
  settings: AppSettings;
  pipelineStatus: PipelineStatus;
  models: Array<{
    id: string;
    label: string;
    runtimeId: RuntimeId;
    detail?: string;
    supportsVision: boolean;
    /** Context window in tokens when honestly known. */
    contextLimit?: number | null;
  }>;
  sidebarOpen: boolean;
  /** Focus mode: hides the persistent desktop sidebar (Ctrl+B). */
  sidebarCollapsed: boolean;
  inspectorOpen: boolean;
  commandPaletteOpen: boolean;

  hydrate: () => Promise<void>;
  refreshChats: () => Promise<void>;
  refreshModels: () => Promise<void>;
  patchSettings: (patch: Record<string, unknown>) => void;
  setSidebarOpen: (open: boolean) => void;
  setSidebarCollapsed: (collapsed: boolean) => void;
  setInspectorOpen: (open: boolean) => void;
  setCommandPaletteOpen: (open: boolean) => void;
}

/** UI layout preferences persist outside the settings schema (pure chrome). */
function readLayoutPref(key: string, fallback: boolean): boolean {
  try {
    const raw = localStorage.getItem(`pocketllm.${key}`);
    return raw === null ? fallback : raw === '1';
  } catch {
    return fallback;
  }
}

function writeLayoutPref(key: string, value: boolean): void {
  try {
    localStorage.setItem(`pocketllm.${key}`, value ? '1' : '0');
  } catch {
    /* storage unavailable — preference just won't persist */
  }
}

export const useAppStore = create<AppState>((set, get) => ({
  hydrated: false,
  chats: [],
  settings: settingsService.get(),
  pipelineStatus: pipeline.status,
  models: [],
  sidebarOpen: false,
  sidebarCollapsed: readLayoutPref('sidebar-collapsed', false),
  inspectorOpen: readLayoutPref('inspector-open', true),
  commandPaletteOpen: false,

  hydrate: async () => {
    await logService.start();
    await inferenceRouter.syncProviders();
    await get().refreshChats();
    await get().refreshModels();
    set({ hydrated: true });

    // Subscribe to every domain change that affects app-level state.
    bus.on('chats:changed', () => void get().refreshChats());
    bus.on('settings:changed', () =>
      set({ settings: settingsService.get() })
    );
    pipeline.onStatus((status) => set({ pipelineStatus: status }));
  },

  refreshChats: async () => {
    const chats = await chatService.listChats();
    set({ chats });
  },

  refreshModels: async () => {
    const models = await inferenceRouter.listAllModels();
    set({ models });
  },

  patchSettings: (patch) => {
    settingsService.patch(patch);
    set({ settings: settingsService.get() });
  },

  setSidebarOpen: (open) => set({ sidebarOpen: open }),
  setSidebarCollapsed: (collapsed) => {
    writeLayoutPref('sidebar-collapsed', collapsed);
    set({ sidebarCollapsed: collapsed });
  },
  setInspectorOpen: (open) => {
    writeLayoutPref('inspector-open', open);
    set({ inspectorOpen: open });
  },
  setCommandPaletteOpen: (open) => set({ commandPaletteOpen: open }),
}));

/* --------------------------- chat store ---------------------------- */

interface ChatState {
  activeChatId: string | null;
  messages: import('@/lib/types/domain').Message[];
  toolEvents: import('@/lib/types/domain').ToolEvent[];
  /** Streaming content overrides keyed by message id (instant UI). */
  streaming: Record<string, string>;
  loading: boolean;

  open: (chatId: string | null) => Promise<void>;
  refresh: () => Promise<void>;
}

export const useChatStore = create<ChatState>((set, get) => ({
  activeChatId: null,
  messages: [],
  toolEvents: [],
  streaming: {},
  loading: false,

  open: async (chatId) => {
    set({ activeChatId: chatId, messages: [], toolEvents: [], streaming: {}, loading: true });
    if (!chatId) {
      set({ loading: false });
      return;
    }
    const messages = await chatService.visibleMessages(chatId);
    const { toolEventRepo } = await import('@/lib/core/db/repositories');
    const events: import('@/lib/types/domain').ToolEvent[] = [];
    for (const m of messages) {
      for (const id of m.toolEvents) {
        const ev = await toolEventRepo.get(id);
        if (ev) events.push(ev);
      }
    }
    if (get().activeChatId !== chatId) return; // switched away meanwhile
    set({ messages, toolEvents: events, loading: false });

    // Live subscriptions for this chat.
    const unsubMessages = bus.on('messages:changed', ({ chatId: changed }) => {
      if (changed === get().activeChatId) void get().refresh();
    });
    const unsubStream = pipeline.onStream((frame) => {
      if (frame.chatId !== get().activeChatId) return;
      set((s) => ({
        streaming: { ...s.streaming, [frame.messageId]: frame.content },
      }));
    });
    const unsubStatus = pipeline.onStatus(() => {
      // Clear the streaming overlay when the pipeline goes idle.
      const st = pipeline.status.state;
      if (['completed', 'cancelled', 'error', 'idle'].includes(st)) {
        set({ streaming: {} });
      }
    });
    // Store unsubs on the closure of the NEXT open call.
    (get as unknown as { _unsubs?: Array<() => void> })._unsubs?.forEach((f) => f());
    (get as unknown as { _unsubs?: Array<() => void> })._unsubs = [
      unsubMessages,
      unsubStream,
      unsubStatus,
    ];
  },

  refresh: async () => {
    const chatId = get().activeChatId;
    if (!chatId) return;
    const messages = await chatService.visibleMessages(chatId);
    const { toolEventRepo } = await import('@/lib/core/db/repositories');
    const events: import('@/lib/types/domain').ToolEvent[] = [];
    for (const m of messages) {
      for (const id of m.toolEvents) {
        const ev = await toolEventRepo.get(id);
        if (ev) events.push(ev);
      }
    }
    if (get().activeChatId !== chatId) return;
    // Preserve streaming overlays for messages currently streaming.
    set({ messages, toolEvents: events });
  },
}));
