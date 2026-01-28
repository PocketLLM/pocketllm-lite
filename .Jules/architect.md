# Architect's Journal

## 2025-02-18 - Media Gallery Aggregation
**Challenge:** Implementing a "Media Gallery" without a dedicated image database table or index, while ensuring data consistency with chat history.
**Solution:** Implemented an on-the-fly aggregation method `getAllImages()` in `StorageService`. It iterates through all `ChatSession` objects (which are cached in memory/Hive) and extracts images into `MediaItem` DTOs.
**Reusable Pattern:** For local-first apps using Hive or similar NoSQL stores where datasets are moderate, aggregating "secondary views" (like media, links, or file attachments) on demand is simpler and less error-prone than maintaining a separate synchronized index. Use `Future.microtask` to offload this iteration from the immediate build phase if needed.
