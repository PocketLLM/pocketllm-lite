import { Navigate, Route, Routes } from "react-router-dom";
import { useEffect } from "react";
import { ensureDefaults } from "../db/db";
import { AppShell } from "../features/shell/AppShell";
import { ChatPage } from "../features/chat/ChatPage";
import { HistoryPage } from "../features/history/HistoryPage";
import { KnowledgePage } from "../features/knowledge/KnowledgePage";
import { ModelsPage } from "../features/models/ModelsPage";
import { SettingsPage } from "../features/settings/SettingsPage";

export function App() {
  useEffect(() => {
    void ensureDefaults();
  }, []);

  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<ChatPage />} />
        <Route path="chat/:chatId" element={<ChatPage />} />
        <Route path="chats" element={<HistoryPage />} />
        <Route path="knowledge" element={<KnowledgePage />} />
        <Route path="models" element={<ModelsPage />} />
        <Route path="settings" element={<SettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
