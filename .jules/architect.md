# Architect's Journal

## 2026-05-24 - Data Export Flexibility
**Challenge:** Users need to export data in various formats (CSV, PDF) for reporting or external analysis, but the app only supported JSON backup.
**Solution:** I implemented a flexible export system in `StorageService` that can format data into JSON, CSV, or MD (Markdown) based on user selection.
**Reusable Pattern:** The `ExportDialog` now uses a format selector and delegates the formatting logic to `StorageService` or dedicated helper classes, keeping the UI clean.

## 2026-05-24 - Testing Private Hive Dependencies
**Challenge:** Testing logic within `StorageService` that relies on private Hive boxes (like `_settingsBox`) is difficult without initializing the full Hive environment, which is slow and complex for unit tests.
**Solution:** I refactored the data access logic (e.g., `_getExportableSettings`) into a protected/visible method (`getExportableSettings` with `@visibleForTesting`).
**Reusable Pattern:** This allows test subclasses (e.g., `TestStorageService`) to override these methods and inject mock data, enabling verification of higher-level logic (like export orchestration) without touching the actual database.
