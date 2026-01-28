# Architect's Journal

## 2026-05-24 - Data Export Flexibility
**Challenge:** Users need to export data in various formats (CSV, PDF) for reporting or external analysis, but the app only supported JSON backup.
**Solution:** I implemented a flexible export system in `StorageService` that can format data into JSON, CSV, or MD (Markdown) based on user selection.
**Reusable Pattern:** The `ExportDialog` now uses a format selector and delegates the formatting logic to `StorageService` or dedicated helper classes, keeping the UI clean.

## 2026-05-24 - Testing Private Hive Dependencies
**Challenge:** Testing logic within `StorageService` that relies on private Hive boxes (like `_settingsBox`) is difficult without initializing the full Hive environment, which is slow and complex for unit tests.
**Solution:** I refactored the data access logic (e.g., `_getExportableSettings`) into a protected/visible method (`getExportableSettings` with `@visibleForTesting`).
**Reusable Pattern:** This allows test subclasses (e.g., `TestStorageService`) to override these methods and inject mock data, enabling verification of higher-level logic (like export orchestration) without touching the actual database.

## 2026-05-25 - Custom Charting without Dependencies
**Challenge:** Implementing visual analytics (bar charts) for usage stats without adding heavy external dependencies like `fl_chart` to keep the app lightweight.
**Solution:** I implemented a custom `BarChartPainter` using Flutter's `CustomPaint` API. It handles dynamic scaling, zero-value placeholders, and theme-aware styling (using `Color.withValues`).
**Reusable Pattern:** The `BarChartPainter` pattern separates the data model (`DailyActivity`) from the rendering logic, providing a lightweight template for other simple time-series visualizations.

## 2026-05-25 - Denormalized Tag Management
**Challenge:** Implementing global tag operations (rename/delete) efficiently when tags are stored per-chat in a NoSQL (Hive) environment without a central index.
**Solution:** I utilized a separate, denormalized `Map<ChatId, List<Tags>>` stored in `settingsBox` (key: `chat_tags`). Global operations iterate this map (O(N) chats) rather than opening every `ChatSession` object.
**Reusable Pattern:** For metadata that cuts across many entities (like tags), store a lightweight index/map in a "settings" or "index" box to allow global querying and manipulation without loading heavy entity objects.
