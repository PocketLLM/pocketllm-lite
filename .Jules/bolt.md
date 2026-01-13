## 2024-05-22 - [Example Entry]
**Learning:** This is an example entry.
**Action:** Create a new entry when you learn something critical.

## 2025-01-13 - [Sync vs Async Decoding in Chat Bubbles]
**Learning:** `base64Decode` is synchronous. When rendering chat bubbles with images, doing this on the main thread during `build` or `initState` causes jank. Moving it to `Isolate.run` (via `compute`) solves this.
**Action:** Always offload image decoding to an isolate if handling base64 strings manually. Also, guard expensive operations in `didUpdateWidget` with deep equality checks (`listEquals`) to prevent re-running on unrelated updates (like streaming text).
