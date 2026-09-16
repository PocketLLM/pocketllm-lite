'use client';

/**
 * Route registry — maps hash segments to feature views.
 *
 * Each feature module replaces its stub component in
 * `src/features/app/<module>/`. This file is the single integration
 * point; feature work never touches shared files.
 */
import { useMemo } from 'react';
import { router } from '@/lib/core/router';

import { HomeView } from '@/features/app/home/home-view';
import { ChatView } from '@/features/app/chat/chat-view';
import { HistoryView } from '@/features/app/chats/history-view';
import { StarredView } from '@/features/app/starred/starred-view';
import { KnowledgeView } from '@/features/app/knowledge/knowledge-view';
import { DocumentView } from '@/features/app/knowledge/document-view';
import { ModelsView } from '@/features/app/models/models-view';
import { ModelDiscoverView } from '@/features/app/models/discover-view';
import { ModelDetailView } from '@/features/app/models/model-detail-view';
import { ProvidersView } from '@/features/app/providers/providers-view';
import { MemoriesView } from '@/features/app/memories/memories-view';
import { PersonasView } from '@/features/app/personas/personas-view';
import { PromptsView } from '@/features/app/prompts/prompts-view';
import { SkillsView } from '@/features/app/skills/skills-view';
import { TagsView } from '@/features/app/tags/tags-view';
import { NotesView } from '@/features/app/notes/notes-view';
import { AudioView } from '@/features/app/audio/audio-view';
import { PromptLabView } from '@/features/app/lab/prompt-lab-view';
import { CompareView } from '@/features/app/lab/compare-view';
import { BenchmarkView } from '@/features/app/lab/benchmark-view';
import { ActivityView } from '@/features/app/activity/activity-view';
import { NetworkView } from '@/features/app/network/network-view';
import { ErrorsView } from '@/features/app/errors/errors-view';
import { SettingsView } from '@/features/app/settings/settings-view';
import { WizardView } from '@/features/app/settings/wizard-view';

export function RouteContent({ segments }: { segments: string[] }) {
  const [head, second, third] = segments;

  return useMemo(() => {
    switch (head) {
      case undefined:
      case '':
        return <HomeView />;
      case 'chat':
        return <ChatView chatId={second ?? null} />;
      case 'chats':
        // /app/chats/archived opens history pre-filtered to archived.
        return <HistoryView initialFilter={second === 'archived' ? 'archived' : undefined} />;
      case 'starred':
        return <StarredView />;
      case 'knowledge':
        return second ? <DocumentView documentId={second} /> : <KnowledgeView />;
      case 'models':
        if (second === 'discover') return <ModelDiscoverView />;
        return second ? <ModelDetailView modelId={second} /> : <ModelsView />;
      case 'providers':
        return <ProvidersView />;
      case 'memories':
        return <MemoriesView />;
      case 'personas':
        return <PersonasView />;
      case 'prompts':
        return <PromptsView />;
      case 'skills':
        return <SkillsView />;
      case 'tags':
        return <TagsView />;
      case 'notes':
        return <NotesView />;
      case 'audio':
        return <AudioView />;
      case 'lab':
        if (second === 'compare') return <CompareView />;
        if (second === 'benchmark') return <BenchmarkView />;
        return <PromptLabView />;
      case 'activity':
        return <ActivityView />;
      case 'network':
        return <NetworkView />;
      case 'errors':
        return <ErrorsView />;
      case 'settings':
        return <SettingsView section={second ?? 'general'} />;
      case 'wizard':
        return <WizardView />;
      default:
        return (
          <div className="flex flex-1 flex-col items-center justify-center gap-3 p-8 text-center">
            <h1 className="font-display text-2xl font-semibold">Page not found</h1>
            <button
              className="rounded-lg border px-4 py-2 text-sm hover:bg-muted"
              onClick={() => router.navigate('/app')}
            >
              Back home
            </button>
          </div>
        );
    }
  }, [head, second, third]);
}
