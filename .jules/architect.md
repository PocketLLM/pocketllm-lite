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

## 2026-05-26 - On-the-fly Media Aggregation
**Challenge:** Users needed a way to view all shared images (Media Gallery) without the overhead of maintaining a separate "Image Index" database that could get out of sync.
**Solution:** I implemented `StorageService.getAllImages` which aggregates images from all `ChatSession` objects on-the-fly. This leverages Hive's in-memory caching of sessions, making it fast enough for typical usage without data duplication.
**Reusable Pattern:** For read-heavy, low-write auxiliary views (like galleries or stats), deriving state from the primary source of truth (Sessions) is safer and simpler than maintaining parallel state.
