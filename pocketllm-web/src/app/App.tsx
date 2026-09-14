import { Navigate, Route, Routes } from "react-router-dom";
import { useEffect } from "react";
import { ensureDefaults } from "../db/db";
import { AppShell } from "../features/shell/AppShell";
import { ChatPage } from "../features/chat/ChatPage";
import { HistoryPage, StarredPage } from "../features/history/HistoryPage";
import { TagsPage } from "../features/history/TagsPage";
import { KnowledgePage } from "../features/knowledge/KnowledgePage";
import { DocumentPage } from "../features/knowledge/DocumentPage";
import { ModelsPage } from "../features/models/ModelsPage";
import { ModelDetailPage } from "../features/models/ModelDetailPage";
import { ProvidersPage } from "../features/models/ProvidersPage";
import { SettingsPage } from "../features/settings/SettingsPage";
import { StoragePage } from "../features/settings/StoragePage";
import { PersonasPage, PromptsPage } from "../features/library/PersonaPromptPages";
import { MemoriesPage, NotesPage, SkillsPage } from "../features/library/SkillMemoryNotePages";
import { AudioPage } from "../features/audio/AudioPage";
import { LabPage } from "../features/lab/LabPage";
import { ActivityPage, ErrorLogPage } from "../features/logs/LogsPage";
import { NetworkPage } from "../features/logs/NetworkPage";
import { StatsPage } from "../features/stats/StatsPage";
import { BootExperience } from "./BootExperience";
import { bootReminderScheduler, stopReminderScheduler } from "../core/reminders";

export function App() {
  useEffect(() => {
    void ensureDefaults();
    bootReminderScheduler();
    return () => stopReminderScheduler();
  }, []);

  return (
    <BootExperience>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<ChatPage />} />
          <Route path="chat/:chatId" element={<ChatPage />} />
          <Route path="chats" element={<HistoryPage />} />
          <Route path="chats/archived" element={<HistoryPage mode="archived" />} />
          <Route path="starred" element={<StarredPage />} />
          <Route path="tags" element={<TagsPage />} />
          <Route path="knowledge" element={<KnowledgePage />} />
          <Route path="knowledge/:documentId" element={<DocumentPage />} />
          <Route path="models" element={<ModelsPage />} />
          <Route path="models/discover" element={<ModelsPage />} />
          <Route path="models/:modelId" element={<ModelDetailPage />} />
          <Route path="providers" element={<ProvidersPage />} />
          <Route path="memories" element={<MemoriesPage />} />
          <Route path="personas" element={<PersonasPage />} />
          <Route path="prompts" element={<PromptsPage />} />
          <Route path="skills" element={<SkillsPage />} />
          <Route path="notes" element={<NotesPage />} />
          <Route path="audio" element={<AudioPage />} />
          <Route path="lab/prompt" element={<LabPage mode="prompt" />} />
          <Route path="lab/compare" element={<LabPage mode="compare" />} />
          <Route path="lab/benchmark" element={<LabPage mode="benchmark" />} />
          <Route path="activity" element={<ActivityPage />} />
          <Route path="network" element={<NetworkPage />} />
          <Route path="errors" element={<ErrorLogPage />} />
          <Route path="stats" element={<StatsPage />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="settings/storage" element={<StoragePage />} />
          <Route path="settings/*" element={<SettingsPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BootExperience>
  );
}
