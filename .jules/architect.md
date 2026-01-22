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

## 2026-05-25 - Starred Messages (Bookmarks)
**Challenge:** Users needed a way to save specific messages without pinning entire chats. Modifying the immutable `ChatMessage` Hive adapter to add an `isStarred` field would require complex data migration and break existing backups.
**Solution:** I implemented a "sidecar" storage pattern where starred messages are stored as a separate list of JSON objects in the global `SettingsBox`. This decouples the bookmark status from the message entity itself.
**Reusable Pattern:** For auxiliary metadata (tags, bookmarks, favorites) that doesn't strictly belong to the entity's domain model, store it in a separate collection referenced by ID. This keeps the core domain models clean and avoids schema migrations for UI-only features.
