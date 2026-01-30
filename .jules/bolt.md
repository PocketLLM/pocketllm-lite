## 2024-05-22 - [Streaming Text Rebuilds]
**Learning:** Streaming text response token-by-token (or chunk-by-chunk) directly into the state triggers a rebuild of the entire message bubble on every update. When using `flutter_markdown`, this causes the entire Markdown document to be re-parsed and re-laid out for every single token, leading to massive UI thread jank on fast streams.
**Action:** Throttle state updates for streaming content (e.g., to 20-30 FPS) to decouple the stream processing rate from the UI render rate. This preserves responsiveness while preventing the UI thread from being overwhelmed by layout calculations.

## 2024-10-27 - [NDJSON Streaming Anti-pattern]
**Learning:** Manual string splitting (`chunk.split('\n')`) on network streams is unsafe and inefficient. It causes data loss when JSON objects are split across chunks and generates unnecessary string allocations.
**Action:** Always use `LineSplitter` (or `Stream.transform(LineSplitter())`) when processing line-delimited streams (like NDJSON) in Dart to correctly buffer partial lines and optimize memory usage.

## 2024-05-24 - [Heavy Object Hashing]
**Learning:** Objects with large data fields (like lists of base64 images) incur massive O(N) costs when used as keys in Widgets (e.g. `ValueKey`) or Collections because `hashCode` is computed repeatedly.
**Action:** Enforce immutability (e.g. `List.unmodifiable`) in the constructor and cache the `hashCode` to turn this into an O(1) operation after the first access.

## 2024-05-25 - [Hive Box Rebuild Scope]
**Learning:** Using `box.listenable()` on a Hive box that stores mixed data types (settings, tags, drafts) triggers rebuilds for all listeners on ANY change. For UI components dependent on a single key (like starred messages), this causes unnecessary re-renders when unrelated data changes.
**Action:** Use `box.listenable(keys: ['specific_key'])` to scope rebuilds, and implement in-memory caching (e.g., `Set`) for expensive derived data to avoid repeated deserialization during builds.

## 2024-05-26 - [ValueListenableBuilder Child Caching]
**Learning:** `ValueListenableBuilder` rebuilds its builder function on every notification. If the builder constructs an expensive widget tree (like `MarkdownBody` or `Image`) that doesn't depend on the value being listened to, it causes unnecessary rebuilds.
**Action:** Extract the expensive, static parts of the subtree and pass them to the `child` parameter of `ValueListenableBuilder`. This ensures the expensive subtree is built only once (or when dependencies change) and reused across notification rebuilds.
