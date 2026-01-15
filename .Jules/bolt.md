## 2024-05-22 - [Example Entry]
**Learning:** This is an example entry.
**Action:** Create a new entry when you learn something critical.

## 2025-01-13 - [Sync vs Async Decoding in Chat Bubbles]
**Learning:** `base64Decode` is synchronous. When rendering chat bubbles with images, doing this on the main thread during `build` or `initState` causes jank. Moving it to `Isolate.run` (via `compute`) solves this.
**Action:** Always offload image decoding to an isolate if handling base64 strings manually. Also, guard expensive operations in `didUpdateWidget` with deep equality checks (`listEquals`) to prevent re-running on unrelated updates (like streaming text).

## 2025-02-18 - [Widget Equality Optimization for Streaming Lists]
**Learning:** In streaming applications where a parent list rebuilds frequently (e.g., chat), children widgets rebuild unnecessarily even if their data hasn't changed. By overriding `operator ==` and `hashCode` in the child widget to check for model identity, we can leverage Flutter's Element update optimization to skip build/layout/paint for unchanged items.
**Action:** Implement `operator ==` and `hashCode` overrides for list items in high-frequency update scenarios, ensuring the underlying data model uses stable object identities.

## 2025-10-27 - [Value Equality for Domain Models to Support Widget Optimization]
**Learning:** Widget-level `operator ==` optimizations (like in `ChatBubble`) fail if the underlying data model relies on identity equality but instances are recreated (e.g., from Hive or `copyWith`). This causes unnecessary rebuilds even when content is identical.
**Action:** Implement value-based equality (`operator ==` and `hashCode`) for core domain models used in high-frequency lists to allow widgets to detect "same content" efficiently, regardless of object identity.

## 2025-05-23 - [Optimizing Streaming Lists with Isolated Consumers]
**Learning:** Watching a whole provider in a `ListView` parent forces full list rebuilds on every item update (e.g., streaming token). Using `select` for the list and isolating the streaming item in a separate `ConsumerWidget` reduces parent rebuilds from O(N) to O(1).
**Action:** When implementing streaming lists, always isolate the active/changing item in a dedicated widget that watches the specific streaming property.
