## 2024-05-22 - [Streaming Text Rebuilds]
**Learning:** Streaming text response token-by-token (or chunk-by-chunk) directly into the state triggers a rebuild of the entire message bubble on every update. When using `flutter_markdown`, this causes the entire Markdown document to be re-parsed and re-laid out for every single token, leading to massive UI thread jank on fast streams.
**Action:** Throttle state updates for streaming content (e.g., to 20-30 FPS) to decouple the stream processing rate from the UI render rate. This preserves responsiveness while preventing the UI thread from being overwhelmed by layout calculations.

## 2024-10-27 - [NDJSON Streaming Anti-pattern]
**Learning:** Manual string splitting (`chunk.split('\n')`) on network streams is unsafe and inefficient. It causes data loss when JSON objects are split across chunks and generates unnecessary string allocations.
**Action:** Always use `LineSplitter` (or `Stream.transform(LineSplitter())`) when processing line-delimited streams (like NDJSON) in Dart to correctly buffer partial lines and optimize memory usage.

## 2024-05-24 - [Heavy Object Hashing]
**Learning:** Objects with large data fields (like lists of base64 images) incur massive O(N) costs when used as keys in Widgets (e.g. `ValueKey`) or Collections because `hashCode` is computed repeatedly.
**Action:** Enforce immutability (e.g. `List.unmodifiable`) in the constructor and cache the `hashCode` to turn this into an O(1) operation after the first access.
